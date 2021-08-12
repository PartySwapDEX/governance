pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * Contract to control the release of YAY.
 */
contract TreasuryVester is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public yay;
    address public recipient;

    // Amount to distribute at each interval in wei
    // 16,450 YAY
    uint256 public vestingAmount = 16_450_000_000_000_000_000_000;

    // Interval to distribute in seconds
    uint256 public vestingCliff = 86_400;

    // Number of distribution intervals before the distribution amount halves
    // Halving should occur once every four years (no leap day).
    // At one distribution per day, that's 365 * 4 = 1460
    uint256 public halvingPeriod = 1460;

    // Countdown till the nest halving in seconds
    uint256 public nextSlash;

    bool public vestingEnabled;

    // Timestamp of latest distribution
    uint256 public lastUpdate;

    // Amount of YAY required to start distributing denominated in wei
    // Should be 48,125,000 YAY
    uint256 public startingBalance = 48_125_000_000_000_000_000_000_000;

    event VestingEnabled();
    event TokensVested(uint256 amount, address recipient);
    event RecipientChanged(address recipient);

    // YAY Distribution plan:
    // According to the Pangolin Litepaper, we initially will distribute
    // 175342.465 YAY per day. Vesting period will be 24 hours: 86400 seconds.
    // Halving will occur every four years. No leap day. 4 years: 1460 distributions

    constructor(address yay_) {
        yay = yay_;

        lastUpdate = 0;
        nextSlash = halvingPeriod;
    }

    /**
     * Enable distribution. A sufficient amount of YAY >= startingBalance must be transferred
     * to the contract before enabling. The recipient must also be set. Can only be called by
     * the owner.
     */
    function startVesting() external onlyOwner {
        require(
            !vestingEnabled,
            "TreasuryVester::startVesting: vesting already started"
        );
        require(
            IERC20(yay).balanceOf(address(this)) >= startingBalance,
            "TreasuryVester::startVesting: incorrect YAY supply"
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
     * Vest the next YAY allocation. Requires vestingCliff seconds in between calls. YAY will
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
            vestingAmount = vestingAmount / 2;
        } else {
            nextSlash = nextSlash.sub(1);
        }

        // Update the timelock
        lastUpdate = block.timestamp;

        // Distribute the tokens
        IERC20(yay).safeTransfer(recipient, vestingAmount);
        emit TokensVested(vestingAmount, recipient);

        return vestingAmount;
    }
}
