// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IBEP20.sol";
import "../libraries/SafeBEP20.sol";
import "../interfaces/ILuckyPower.sol";

interface ILCDice {
    function deposit(uint256 _tokenAmount) external;
    function withdraw(uint256 _diceTokenAmount) external;
}

interface IChef {
    function deposit(uint256 _pid, uint256 _amount, address _referrer) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
    function claimLC(uint256 _pid) external;
}

contract Vesting is Ownable, ReentrancyGuard {
    using SafeBEP20 for IBEP20;
    using SafeMath for uint256;

    // LC Token
    IBEP20 public immutable LC;

    // LCDiceToken
    IBEP20 public lcDiceToken;

    // Dice contract
    ILCDice public lcDice;

    // MasterChef contract
    IChef public masterChef;

    // LuckyPower contract
    ILuckyPower public luckyPower;

    // Start block for the linear vesting
    uint256 public immutable START_BLOCK;

    // Lock period in blocks
    uint256 public immutable LOCK_PERIODS_IN_BLOCKS;

    // block number for unlock
    uint256 public unlockBlock;

    // total diceToken deposited to MasterChef
    uint256 public depositedAmount;

    event OtherTokensWithdrawn(address indexed currency, uint256 amount);
    event TokensWithdrawn(uint256 amount);

    /**
     * @notice Constructor
     * @param _startBlock block number for start (must be same as MasterChef)
     * @param _lockPeriodsInBlocks lock period length in blocks
     * @param _LC address of the LC token
     */
    constructor(
        uint256 _startBlock,
        uint256 _lockPeriodsInBlocks,
        address _LC,
        address _lcDice,
        address _lcDiceToken,
        address _masterChef,
        address _luckyPower
    ) public {
        START_BLOCK = _startBlock;
        LOCK_PERIODS_IN_BLOCKS = _lockPeriodsInBlocks;
        unlockBlock = _startBlock + _lockPeriodsInBlocks;
        LC = IBEP20(_LC);
        lcDice = ILCDice(_lcDice);
        lcDiceToken = IBEP20(_lcDiceToken);
        masterChef = IChef(_masterChef);
        luckyPower = ILuckyPower(_luckyPower);
    }

    /**
     * @notice Withdraw LC tokens
     * @dev It includes protection for overstaking
     */
    function withdrawLC() external nonReentrant onlyOwner {
        require(block.number >= unlockBlock, "Unlock: Too early");

        uint256 balanceToWithdraw = LC.balanceOf(address(this));
        // Transfer LC to owner
        LC.safeTransfer(msg.sender, balanceToWithdraw);

        emit TokensWithdrawn(balanceToWithdraw);
    }

    /**
     * @notice Withdraw any currency to the owner (e.g., WBNB)
     * @param _currency address of the currency to withdraw
     */
    function withdrawOtherCurrency(address _currency) external nonReentrant onlyOwner {
        require(_currency != address(LC), "Owner: Cannot withdraw LC");

        uint256 balanceToWithdraw = IBEP20(_currency).balanceOf(address(this));

        // Transfer token to owner if not null
        require(balanceToWithdraw != 0, "Owner: Nothing to withdraw");
        IBEP20(_currency).safeTransfer(msg.sender, balanceToWithdraw);

        emit OtherTokensWithdrawn(_currency, balanceToWithdraw);
    }

    /**
     * @notice Bank LC to LCDice and stake the LCDiceToken to MasterChef
     * @param _pid Pool id in MasterChef
     * @param _amount Amount to deposit
     * @param _referrer Referrer
     */
    function bankLC(uint256 _pid, uint256 _amount, address _referrer) external nonReentrant onlyOwner {
        uint256 balanceToDeposit = LC.balanceOf(address(this));
        require(_amount <= balanceToDeposit, 'Not enough LC');

        LC.approve(address(lcDice), _amount);
        lcDice.deposit(_amount);
        uint256 diceTokenBalance = lcDiceToken.balanceOf(address(this));
        lcDiceToken.approve(address(masterChef), diceTokenBalance);
        depositedAmount = depositedAmount.add(diceTokenBalance);
        masterChef.deposit(_pid, diceTokenBalance, _referrer);
    }

    /**
     * @notice Withdraw from MasterChef and get lcDiceToken, then withdraw from Dice
     * @param _pid Pool id in MasterChef
     * @param _amount Amount to withdraw
     */
    function unbankLC(uint256 _pid, uint256 _amount) external nonReentrant onlyOwner {
        require(_amount <= depositedAmount, 'Deposited amount not enough ');

        depositedAmount = depositedAmount.sub(_amount);
        masterChef.withdraw(_pid, _amount);
        uint256 diceTokenBalance = lcDiceToken.balanceOf(address(this));
        lcDiceToken.approve(address(lcDice), diceTokenBalance);
        lcDice.withdraw(diceTokenBalance);
    }

    /**
     * @notice Claim LC from MasterChef
     * @param _pid Pool id in MasterChef
     */
    function claimChefLC(uint256 _pid) external nonReentrant onlyOwner {
        masterChef.claimLC(_pid);
    }

    /**
     * @notice Claim LC from MasterChef
     */
    function claimLuckyBonus() external nonReentrant onlyOwner {
        luckyPower.withdraw();
    }
}
