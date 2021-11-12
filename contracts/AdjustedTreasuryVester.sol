pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * Contract to control the release of PARTY.
 */
contract AdjustedTreasuryVester is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public party;
    address public recipient;

    // Amount to distribute at each interval in wei
    // 16,450 x 8 PARTY = 131,600
    uint256 public vestingAmount = 131_600_000_000_000_000_000_000;

    // Interval to distribute in seconds
    uint256 public vestingCliff = 86_400;

    // Number of distribution intervals before the distribution amount halves
    // Halving should occur once every month

    // 0.75 period
    uint256 public halvingPeriod = 30;

    // Countdown till the nest halving in days
    uint256 public nextSlash;

    bool public vestingEnabled;

    // Timestamp of latest distribution
    uint256 public lastUpdate;

    // Amount of PARTY required to start distributing denominated in wei
    // Should be 394,801 PARTY - just for deployment days
    uint256 public startingBalance = 394_801_000_000_000_000_000_000;

    event VestingEnabled();
    event TokensVested(uint256 amount, address recipient);
    event RecipientChanged(address recipient);

    // PARTY Distribution plan:
    // According to the Pangolin Litepaper, we initially will distribute
    // 175342.465 PARTY per day. Vesting period will be 24 hours: 86400 seconds.
    // Halving will occur every four years. No leap day. 4 years: 1460 distributions

    constructor(address party_) {
        party = party_;

        lastUpdate = 0;
        nextSlash = halvingPeriod;
    }

    /**
     * Enable distribution. A sufficient amount of PARTY >= startingBalance must be transferred
     * to the contract before enabling. The recipient must also be set. Can only be called by
     * the owner.
     */
    function startVesting() external onlyOwner {
        require(
            !vestingEnabled,
            "TreasuryVester::startVesting: vesting already started"
        );
        require(
            IERC20(party).balanceOf(address(this)) >= startingBalance,
            "TreasuryVester::startVesting: incorrect PARTY supply"
        );
        require(
            recipient != address(0),
            "TreasuryVester::startVesting: recipient not set"
        );
        vestingEnabled = true;

        emit VestingEnabled();
    }

    /**
     * Sets the recipient of the vested distributions. In the initial Pangolin scheme, this
     * should be the address of the LiquidityPoolManager. Can only be called by the contract
     * owner.
     */
    function setRecipient(address recipient_) external onlyOwner {
        require(
            recipient_ != address(0),
            "TreasuryVester::setRecipient: Recipient can't be the zero address"
        );
        recipient = recipient_;
        emit RecipientChanged(recipient);
    }

    /**
     * Vest the next PARTY allocation. Requires vestingCliff seconds in between calls. PARTY will
     * be distributed to the recipient.
     */
    function claim() external nonReentrant returns (uint256) {
        require(vestingEnabled, "TreasuryVester::claim: vesting not enabled");
        require(
            msg.sender == recipient,
            "TreasuryVester::claim: only recipient can claim"
        );
        require(
            block.timestamp >= lastUpdate + vestingCliff,
            "TreasuryVester::claim: not time yet"
        );

        // If we've finished a halving period, reduce the amount
        if (nextSlash == 0) {
            nextSlash = halvingPeriod - 1;
            vestingAmount = (vestingAmount * 3) / 4;
        } else {
            nextSlash = nextSlash.sub(1);
        }

        // Update the timelock
        lastUpdate = block.timestamp;

        // Distribute the tokens
        IERC20(party).safeTransfer(recipient, vestingAmount);
        emit TokensVested(vestingAmount, recipient);

        return vestingAmount;
    }
}
