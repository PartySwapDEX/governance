pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./StakingRewards.sol";

/**
 * Contract to distribute PARTY tokens to whitelisted trading pairs. After deploying,
 * whitelist the desired pairs and set the avaxPartyPair. When initial administration
 * is complete. Ownership should be transferred to the Timelock governance contract.
 */
contract LiquidityPoolManager is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    // Whitelisted pairs that offer PARTY rewards
    // Note: AVAX/PARTY is an AVAX pair
    EnumerableSet.AddressSet private avaxPairs;
    EnumerableSet.AddressSet private partyPairs;

    // Maps pairs to their associated StakingRewards contract
    mapping(address => address) public stakes;

    // Map of pools to weights
    mapping(address => uint256) public weights;

    // Fields to control potential fee splitting
    bool public splitPools;
    uint256 public avaxSplit;
    uint256 public partySplit;

    // Known contract addresses for WAVAX and PARTY
    address public wavax;
    address public party;

    // AVAX/PARTY pair used to determine PARTY liquidity
    address public avaxPartyPair;

    // TreasuryVester contract that distributes PARTY
    address public treasuryVester;

    uint256 public numPools = 0;

    bool private readyToDistribute = false;

    // Tokens to distribute to each pool. Indexed by avaxPairs then partyPairs.
    uint256[] public distribution;

    uint256 public unallocatedParty = 0;

    constructor(
        address wavax_,
        address party_,
        address treasuryVester_
    ) {
        require(
            wavax_ != address(0) &&
                party_ != address(0) &&
                treasuryVester_ != address(0),
            "LPM::constructor: Arguments can't be the zero address"
        );
        wavax = wavax_;
        party = party_;
        treasuryVester = treasuryVester_;
    }

    /**
     * Check if the given pair is a whitelisted pair
     *
     * Args:
     *   pair: pair to check if whitelisted
     *
     * Return: True if whitelisted
     */
    function isWhitelisted(address pair) public view returns (bool) {
        return avaxPairs.contains(pair) || partyPairs.contains(pair);
    }

    /**
     * Check if the given pair is a whitelisted AVAX pair. The AVAX/PARTY pair is
     * considered an AVAX pair.
     *
     * Args:
     *   pair: pair to check
     *
     * Return: True if whitelisted and pair contains AVAX
     */
    function isAvaxPair(address pair) external view returns (bool) {
        return avaxPairs.contains(pair);
    }

    /**
     * Check if the given pair is a whitelisted PARTY pair. The AVAX/PARTY pair is
     * not considered a PARTY pair.
     *
     * Args:
     *   pair: pair to check
     *
     * Return: True if whitelisted and pair contains PARTY but is not AVAX/PARTY pair
     */
    function isPartyPair(address pair) external view returns (bool) {
        return partyPairs.contains(pair);
    }

    /**
     * Sets the AVAX/PARTY pair. Pair's tokens must be AVAX and PARTY.
     *
     * Args:
     *   pair: AVAX/PARTY pair
     */
    function setavaxPartyPair(address avaxPartyPair_) external onlyOwner {
        require(
            avaxPartyPair_ != address(0),
            "LPM::setavaxPartyPair: Pool cannot be the zero address"
        );
        avaxPartyPair = avaxPartyPair_;
    }

    /**
     * Adds a new whitelisted liquidity pool pair. Generates a staking contract.
     * Liquidity providers may stake this liquidity provider reward token and
     * claim PARTY rewards proportional to their stake. Pair must contain either
     * AVAX or PARTY. Associates a weight with the pair. Rewards are distributed
     * to the pair proportionally based on its share of the total weight.
     *
     * Args:
     *   pair: pair to whitelist
     *   weight: how heavily to distribute rewards to this pool relative to other
     *     pools
     */
    function addWhitelistedPool(address pair, uint256 weight)
        external
        onlyOwner
    {
        require(
            !readyToDistribute,
            "LPM::addWhitelistedPool: Cannot add pool between calculating and distributing returns"
        );
        require(
            pair != address(0),
            "LPM::addWhitelistedPool: Pool cannot be the zero address"
        );
        require(
            isWhitelisted(pair) == false,
            "LPM::addWhitelistedPool: Pool already whitelisted"
        );
        require(weight > 0, "LPM::addWhitelistedPool: Weight cannot be zero");

        address token0 = IPartyPair(pair).token0();
        address token1 = IPartyPair(pair).token1();

        require(
            token0 != token1,
            "LPM::addWhitelistedPool: Tokens cannot be identical"
        );

        // Create the staking contract and associate it with the pair
        address stakeContract = address(new StakingRewards(party, pair));
        stakes[pair] = stakeContract;

        weights[pair] = weight;

        // Add as an AVAX or PARTY pair
        if (token0 == party || token1 == party) {
            require(
                partyPairs.add(pair),
                "LPM::addWhitelistedPool: Pair add failed"
            );
        } else if (token0 == wavax || token1 == wavax) {
            require(
                avaxPairs.add(pair),
                "LPM::addWhitelistedPool: Pair add failed"
            );
        } else {
            // The governance contract can be used to deploy an altered
            // LiquidityPoolManager if non-AVAX/PARTY pools are desired.
            revert("LPM::addWhitelistedPool: No AVAX or PARTY in the pair");
        }

        numPools = numPools.add(1);
    }

    /**
     * Delists a whitelisted pool. Liquidity providers will not receiving future rewards.
     * Already vested funds can still be claimed. Re-whitelisting a delisted pool will
     * deploy a new staking contract.
     *
     * Args:
     *   pair: pair to remove from whitelist
     */
    function removeWhitelistedPool(address pair) external onlyOwner {
        require(
            !readyToDistribute,
            "LPM::removeWhitelistedPool: Cannot remove pool between calculating and distributing returns"
        );
        require(
            isWhitelisted(pair),
            "LPM::removeWhitelistedPool: Pool not whitelisted"
        );

        address token0 = IPartyPair(pair).token0();
        address token1 = IPartyPair(pair).token1();

        stakes[pair] = address(0);
        weights[pair] = 0;

        if (token0 == party || token1 == party) {
            require(
                partyPairs.remove(pair),
                "LPM::removeWhitelistedPool: Pair remove failed"
            );
        } else {
            require(
                avaxPairs.remove(pair),
                "LPM::removeWhitelistedPool: Pair remove failed"
            );
        }
        numPools = numPools.sub(1);
    }

    /**
     * Adjust the weight of an existing pool
     *
     * Args:
     *   pair: pool to adjust weight of
     *   weight: new weight
     */
    function changeWeight(address pair, uint256 weight) external onlyOwner {
        require(weights[pair] > 0, "LPM::changeWeight: Pair not whitelisted");
        require(weight > 0, "LPM::changeWeight: Remove pool instead");
        weights[pair] = weight;
    }

    /**
     * Activates the fee split mechanism. Divides rewards between AVAX
     * and PARTY pools regardless of liquidity. AVAX and PARTY pools will
     * receive a fixed proportion of the pool rewards. The AVAX and PARTY
     * splits should correspond to percentage of rewards received for
     * each and must add up to 100. For the purposes of fee splitting,
     * the AVAX/PARTY pool is a PARTY pool. This method can also be used to
     * change the split ratio after fee splitting has been activated.
     *
     * Args:
     *   avaxSplit: Percent of rewards to distribute to AVAX pools
     *   partySplit: Percent of rewards to distribute to PARTY pools
     */
    function activateFeeSplit(uint256 avaxSplit_, uint256 partySplit_)
        external
        onlyOwner
    {
        require(
            avaxSplit_.add(partySplit_) == 100,
            "LPM::activateFeeSplit: Split doesn't add to 100"
        );
        require(
            !(avaxSplit_ == 100 || partySplit_ == 100),
            "LPM::activateFeeSplit: Split can't be 100/0"
        );
        splitPools = true;
        avaxSplit = avaxSplit_;
        partySplit = partySplit_;
    }

    /**
     * Deactivates fee splitting.
     */
    function deactivateFeeSplit() external onlyOwner {
        require(splitPools, "LPM::deactivateFeeSplit: Fee split not activated");
        splitPools = false;
        avaxSplit = 0;
        partySplit = 0;
    }

    /**
     * Calculates the amount of liquidity in the pair. For an AVAX pool, the liquidity in the
     * pair is two times the amount of AVAX. Only works for AVAX pairs.
     *
     * Args:
     *   pair: AVAX pair to get liquidity in
     *
     * Returns: the amount of liquidity in the pool in units of AVAX
     */
    function getAvaxLiquidity(address pair) public view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = IPartyPair(pair).getReserves();

        uint256 liquidity = 0;

        // add the avax straight up
        if (IPartyPair(pair).token0() == wavax) {
            liquidity = liquidity.add(reserve0);
        } else {
            require(
                IPartyPair(pair).token1() == wavax,
                "LPM::getAvaxLiquidity: One of the tokens in the pair must be WAVAX"
            );
            liquidity = liquidity.add(reserve1);
        }
        liquidity = liquidity.mul(2);
        return liquidity;
    }

    /**
     * Calculates the amount of liquidity in the pair. For a PARTY pool, the liquidity in the
     * pair is two times the amount of PARTY multiplied by the price of AVAX per PARTY. Only
     * works for PARTY pairs.
     *
     * Args:
     *   pair: PARTY pair to get liquidity in
     *   conversionFactor: the price of AVAX to PARTY
     *
     * Returns: the amount of liquidity in the pool in units of AVAX
     */
    function getPartyLiquidity(address pair, uint256 conversionFactor)
        public
        view
        returns (uint256)
    {
        (uint256 reserve0, uint256 reserve1, ) = IPartyPair(pair).getReserves();

        uint256 liquidity = 0;

        // add the party straight up
        if (IPartyPair(pair).token0() == party) {
            liquidity = liquidity.add(reserve0);
        } else {
            require(
                IPartyPair(pair).token1() == party,
                "LPM::getPartyLiquidity: One of the tokens in the pair must be PARTY"
            );
            liquidity = liquidity.add(reserve1);
        }

        uint256 oneToken = 1e18;
        liquidity = liquidity.mul(conversionFactor).mul(2).div(oneToken);
        return liquidity;
    }

    /**
     * Calculates the price of swapping AVAX for 1 PARTY
     *
     * Returns: the price of swapping AVAX for 1 PARTY
     */
    function getAvaxPartyRatio()
        public
        view
        returns (uint256 conversionFactor)
    {
        require(
            !(avaxPartyPair == address(0)),
            "LPM::getAvaxPartyRatio: No AVAX-PARTY pair set"
        );
        (uint256 reserve0, uint256 reserve1, ) = IPartyPair(avaxPartyPair)
            .getReserves();

        if (IPartyPair(avaxPartyPair).token0() == wavax) {
            conversionFactor = quote(reserve1, reserve0);
        } else {
            conversionFactor = quote(reserve0, reserve1);
        }
    }

    /**
     * Determine how the vested PARTY allocation will be distributed to the liquidity
     * pool staking contracts. Must be called before distributeTokens(). Tokens are
     * distributed to pools based on relative liquidity proportional to total
     * liquidity. Should be called after vestAllocation()/
     */
    function calculateReturns() public {
        require(
            !readyToDistribute,
            "LPM::calculateReturns: Previous returns not distributed. Call distributeTokens()"
        );
        require(
            unallocatedParty > 0,
            "LPM::calculateReturns: No PARTY to allocate. Call vestAllocation()."
        );
        if (partyPairs.length() > 0) {
            require(
                !(avaxPartyPair == address(0)),
                "LPM::calculateReturns: Avax/PARTY Pair not set"
            );
        }

        // Calculate total liquidity
        distribution = new uint256[](numPools);
        uint256 avaxLiquidity = 0;
        uint256 partyLiquidity = 0;

        // Add liquidity from AVAX pairs
        for (uint256 i = 0; i < avaxPairs.length(); i++) {
            address pair = avaxPairs.at(i);
            uint256 pairLiquidity = getAvaxLiquidity(pair);
            uint256 weightedLiquidity = pairLiquidity.mul(weights[pair]);
            distribution[i] = weightedLiquidity;
            avaxLiquidity = SafeMath.add(avaxLiquidity, weightedLiquidity);
        }

        // Add liquidity from PARTY pairs
        if (partyPairs.length() > 0) {
            uint256 conversionRatio = getAvaxPartyRatio();
            for (uint256 i = 0; i < partyPairs.length(); i++) {
                address pair = partyPairs.at(i);
                uint256 pairLiquidity = getPartyLiquidity(
                    pair,
                    conversionRatio
                );
                uint256 weightedLiquidity = pairLiquidity.mul(weights[pair]);
                distribution[i + avaxPairs.length()] = weightedLiquidity;
                partyLiquidity = SafeMath.add(
                    partyLiquidity,
                    weightedLiquidity
                );
            }
        }

        // Calculate tokens for each pool
        uint256 transferred = 0;
        if (splitPools) {
            uint256 avaxAllocatedParty = unallocatedParty.mul(avaxSplit).div(
                100
            );
            uint256 partyAllocatedParty = unallocatedParty.sub(
                avaxAllocatedParty
            );

            for (uint256 i = 0; i < avaxPairs.length(); i++) {
                uint256 pairTokens = distribution[i]
                    .mul(avaxAllocatedParty)
                    .div(avaxLiquidity);
                distribution[i] = pairTokens;
                transferred = transferred.add(pairTokens);
            }

            if (partyPairs.length() > 0) {
                for (uint256 i = 0; i < partyPairs.length(); i++) {
                    uint256 pairTokens = distribution[i + avaxPairs.length()]
                        .mul(partyAllocatedParty)
                        .div(partyLiquidity);
                    distribution[i + avaxPairs.length()] = pairTokens;
                    transferred = transferred.add(pairTokens);
                }
            }
        } else {
            uint256 totalLiquidity = avaxLiquidity.add(partyLiquidity);

            for (uint256 i = 0; i < distribution.length; i++) {
                uint256 pairTokens = distribution[i].mul(unallocatedParty).div(
                    totalLiquidity
                );
                distribution[i] = pairTokens;
                transferred = transferred.add(pairTokens);
            }
        }
        readyToDistribute = true;
    }

    /**
     * After token distributions have been calculated, actually distribute the vested PARTY
     * allocation to the staking pools. Must be called after calculateReturns().
     */
    function distributeTokens() public nonReentrant {
        require(
            readyToDistribute,
            "LPM::distributeTokens: Previous returns not allocated. Call calculateReturns()"
        );
        readyToDistribute = false;
        address stakeContract;
        uint256 rewardTokens;
        for (uint256 i = 0; i < distribution.length; i++) {
            if (i < avaxPairs.length()) {
                stakeContract = stakes[avaxPairs.at(i)];
            } else {
                stakeContract = stakes[partyPairs.at(i - avaxPairs.length())];
            }
            rewardTokens = distribution[i];
            if (rewardTokens > 0) {
                require(
                    IPARTY(party).transfer(stakeContract, rewardTokens),
                    "LPM::distributeTokens: Transfer failed"
                );
                StakingRewards(stakeContract).notifyRewardAmount(rewardTokens);
            }
        }
        unallocatedParty = 0;
    }

    /**
     * Fallback for distributeTokens in case of gas overflow. Distributes PARTY tokens to a single pool.
     * distibuteTokens() must still be called once to reset the contract state before calling vestAllocation.
     *
     * Args:
     *   pairIndex: index of pair to distribute tokens to, AVAX pairs come first in the ordering
     */
    function distributeTokensSinglePool(uint256 pairIndex)
        external
        nonReentrant
    {
        require(
            readyToDistribute,
            "LPM::distributeTokensSinglePool: Previous returns not allocated. Call calculateReturns()"
        );
        require(
            pairIndex < numPools,
            "LPM::distributeTokensSinglePool: Index out of bounds"
        );

        address stakeContract;
        if (pairIndex < avaxPairs.length()) {
            stakeContract = stakes[avaxPairs.at(pairIndex)];
        } else {
            stakeContract = stakes[
                partyPairs.at(pairIndex - avaxPairs.length())
            ];
        }

        uint256 rewardTokens = distribution[pairIndex];
        if (rewardTokens > 0) {
            distribution[pairIndex] = 0;
            require(
                IPARTY(party).transfer(stakeContract, rewardTokens),
                "LPM::distributeTokens: Transfer failed"
            );
            StakingRewards(stakeContract).notifyRewardAmount(rewardTokens);
        }
    }

    /**
     * Calculate pool token distribution and distribute tokens. Methods are separate
     * to use risk of approaching the gas limit. There must be vested tokens to
     * distribute, so this method should be called after vestAllocation.
     */
    function calculateAndDistribute() external {
        calculateReturns();
        distributeTokens();
    }

    /**
     * Claim today's vested tokens for the manager to distribute. Moves tokens from
     * the TreasuryVester to the LPM. Can only be called if all
     * previously allocated tokens have been distributed. Call distributeTokens() if
     * that is not the case. If any additional PARTY tokens have been transferred to this
     * this contract, they will be marked as unallocated and prepared for distribution.
     */
    function vestAllocation() external nonReentrant {
        require(
            unallocatedParty == 0,
            "LPM::vestAllocation: Old PARTY is unallocated. Call distributeTokens()."
        );
        unallocatedParty = ITreasuryVester(treasuryVester).claim();
        require(
            unallocatedParty > 0,
            "LPM::vestAllocation: No PARTY to claim. Try again tomorrow."
        );

        // Check if we've received extra tokens or didn't receive enough
        uint256 actualBalance = IPARTY(party).balanceOf(address(this));
        require(
            actualBalance >= unallocatedParty,
            "LPM::vestAllocation: Insufficient PARTY transferred"
        );
        unallocatedParty = actualBalance;
    }

    /**
     * Calculate the equivalent of 1e18 of token A denominated in token B for a pair
     * with reserveA and reserveB reserves.
     *
     * Args:
     *   reserveA: reserves of token A
     *   reserveB: reserves of token B
     *
     * Returns: the amount of token B equivalent to 1e18 of token A
     */
    function quote(uint256 reserveA, uint256 reserveB)
        internal
        pure
        returns (uint256 amountB)
    {
        require(
            reserveA > 0 && reserveB > 0,
            "PartyLibrary: INSUFFICIENT_LIQUIDITY"
        );
        uint256 oneToken = 1e18;
        amountB = SafeMath.div(SafeMath.mul(oneToken, reserveB), reserveA);
    }
}

interface ITreasuryVester {
    function claim() external returns (uint256);
}

interface IPARTY {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address dst, uint256 rawAmount) external returns (bool);
}

interface IPartyPair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function factory() external view returns (address);

    function balanceOf(address owner) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        );
}
