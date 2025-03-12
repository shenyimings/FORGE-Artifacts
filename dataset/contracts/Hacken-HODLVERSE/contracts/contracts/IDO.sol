// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract IDO is Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // IDO Configs
    uint256 public saleStartTime;
    uint256 public saleEndTime;
    uint256 public unlockTime;
    uint256 public saleCap;
    uint256 public exchangeRate;

    uint256 public depositMin;
    uint256 public depositMax;

    uint256 public totalUSDTBalance;
    uint256 public totalMoneyClaimed;

    address public withdrawer;

    IERC20 public USDT;
    IERC20 public MONEY;
    uint256 public constant EXCHANGE_RATE_PRECISION = 10**12;
    uint256 public constant MONEY_DECIMALS = 10**18;
    uint256 public constant USDT_DECIMALS = 10**6;

    mapping(address => uint256) public balanceOf;

    event Deposited(address indexed account, uint256 amount);
    event Claimed(address indexed account, uint256 amount);
    event EmergencyWithdrawals(
        address indexed account,
        address indexed token,
        uint256 amount
    );

    constructor(
        uint256 _saleStartTime,
        uint256 _saleEndTime,
        uint256 _unlockTime,
        uint256 _saleCap,
        uint256 _depositMin,
        uint256 _depositMax,
        uint256 _exchangeRate,
        address _withdrawer,
        address usdtAddr,
        address moneyAddr
    ) public {
        require(_exchangeRate != 0, "MoneyIDO: exchange rate cannot be zero");

        require(
            _withdrawer != address(0),
            "MoneyIDO: Invalid withdrawer address."
        );

        saleStartTime = _saleStartTime;
        saleEndTime = _saleEndTime;
        unlockTime = _unlockTime;
        saleCap = _saleCap;
        depositMin = _depositMin;
        depositMax = _depositMax;
        exchangeRate = _exchangeRate;

        withdrawer = _withdrawer;
        USDT = IERC20(usdtAddr);
        MONEY = IERC20(moneyAddr);
    }

    function setSaleStartTime(uint256 newSaleStartTime) public onlyOwner {
        require(
            newSaleStartTime < saleEndTime,
            "MoneyIDO: Invalid sale start time."
        );
        saleStartTime = newSaleStartTime;
    }

    function setSaleEndTime(uint256 newSaleEndTime) public onlyOwner {
        require(
            newSaleEndTime > saleStartTime && unlockTime > newSaleEndTime,
            "MoneyIDO: Invalid sale end time"
        );
        saleEndTime = newSaleEndTime;
    }

    function setWithdrawer(address newWithdrawer) public onlyOwner {
        require(
            newWithdrawer != address(0),
            "MoneyIDO: Invalid withdrawer address."
        );
        withdrawer = newWithdrawer;
    }

    function setUnlockTime(uint256 newUnlockTime) public onlyOwner {
        require(newUnlockTime > saleEndTime, "MoneyIDO: Invalid unlock time");
        unlockTime = newUnlockTime;
    }

    function setDepositMin(uint256 newDepositMin) public onlyOwner {
        require(newDepositMin != uint256(-1), "MoneyIDO: Invalid min deposit.");
        depositMin = newDepositMin;
    }

    function setDepositMax(uint256 newDepositMax) public onlyOwner {
        require(newDepositMax != 0, "MoneyIDO: Invalid max deposit");
        depositMax = newDepositMax;
    }

    function pause() external onlyOwner whenNotPaused {
        require(
            block.timestamp < unlockTime,
            "MoneyIDO: cannot be paused after unock time"
        );
        _pause();
    }

    function _getMoneyForUSDT(uint256 _usdt)
        internal
        view
        returns (uint256 _money)
    {
        _money = _usdt
            .mul(MONEY_DECIMALS)
            .mul(exchangeRate)
            .div(USDT_DECIMALS)
            .div(EXCHANGE_RATE_PRECISION);
    }

    function deposit(uint256 amount) public whenNotPaused {
        require(
            block.timestamp >= saleStartTime,
            "MoneyIDO: IDO is not started yet."
        );
        require(
            block.timestamp <= saleEndTime,
            "MoneyIDO: IDO is already finished."
        );
        require(
            MONEY.balanceOf(address(this)) >= _getMoneyForUSDT(saleCap),
            "MoneyIDO: MONEY balance not enough"
        );

        uint256 finalAmount = balanceOf[msg.sender].add(amount);
        require(
            finalAmount >= depositMin,
            "MoneyIDO: Does not meet minimum deposit requirements."
        );
        require(
            finalAmount <= depositMax,
            "MoneyIDO: Does not meet maximum deposit requirements."
        );
        require(
            totalUSDTBalance.add(amount) <= saleCap,
            "MoneyIDO: Sale Cap overflow."
        );

        balanceOf[msg.sender] = finalAmount;
        totalUSDTBalance = totalUSDTBalance.add(amount);

        USDT.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function claim() public whenNotPaused {
        require(
            block.timestamp >= unlockTime,
            "MoneyIDO: IDO is not unlocked yet."
        );
        require(balanceOf[msg.sender] > 0, "MoneyIDO: Insufficient balance.");

        uint256 moneyAmount = _getMoneyForUSDT(balanceOf[msg.sender]);

        balanceOf[msg.sender] = 0;
        totalMoneyClaimed = totalMoneyClaimed.add(moneyAmount);

        MONEY.safeTransfer(msg.sender, moneyAmount);
        emit Claimed(msg.sender, moneyAmount);
    }

    function withdraw() public whenNotPaused {
        require(
            msg.sender == withdrawer,
            "MoneyIDO: You can't withdraw funds."
        );
        require(
            block.timestamp >= unlockTime,
            "MoneyIDO: IDO is not unlocked yet."
        );

        uint256 usdtBalance = USDT.balanceOf(address(this));
        USDT.safeTransfer(withdrawer, usdtBalance);
    }

    function withdrawRest() public whenNotPaused {
        require(
            msg.sender == withdrawer,
            "MoneyIDO: You can't withdraw funds."
        );
        require(
            block.timestamp >= unlockTime,
            "MoneyIDO: IDO is not unlocked yet."
        );

        uint256 soldMoneyAmount = _getMoneyForUSDT(totalUSDTBalance);
        uint256 unsoldMoneyBalance = MONEY.balanceOf(address(this)).sub(
            soldMoneyAmount
        );
        MONEY.safeTransfer(withdrawer, unsoldMoneyBalance);
    }

    // In case the contract is paused due to some reason, the users and withdrawer will still
    // be able to pull out the investments through this function
    function emergencyWithdraw() external whenPaused {
        uint256 withdrawAmount;
        address token;
        if (msg.sender == withdrawer) {
            withdrawAmount = MONEY.balanceOf(address(this));
            require(
                withdrawAmount > 0,
                "MoneyIDO:emergencyWithdraw:: Insufficient MONEY balance."
            );

            token = address(MONEY);
            MONEY.safeTransfer(msg.sender, withdrawAmount);
        } else {
            require(
                balanceOf[msg.sender] > 0,
                "MoneyIDO:emergencyWithdraw:: Insufficient USDT balance."
            );

            token = address(USDT);
            withdrawAmount = balanceOf[msg.sender];

            balanceOf[msg.sender] = 0;
            USDT.safeTransfer(msg.sender, withdrawAmount);
        }
        emit EmergencyWithdrawals(msg.sender, token, withdrawAmount);
    }
}
