pragma solidity 0.6.11;

import "../Dependencies/IERC20.sol";
import "../Dependencies/IWETH.sol";
import "../Interfaces/IBorrowerOperations.sol";

contract WETHDelegator {
    IWETH public immutable WETH;
    IERC20 public immutable LUSD;
    IBorrowerOperations public immutable borrowerOperations;

    constructor(
        IWETH _weth,
        IERC20 _lusd,
        address _borrowerOperations
    ) public {
        _weth.approve(_borrowerOperations, uint256(-1));
        WETH = _weth;
        LUSD = _lusd;
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
    }

    receive() external payable {}

    function openTrove(
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _LUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable {
        require(msg.value == _collateralAmount, "Invalid amount");

        WETH.deposit{value: msg.value}();
        borrowerOperations.openTrove(
            msg.sender,
            _maxFeePercentage,
            _collateralAmount,
            _LUSDAmount,
            _upperHint,
            _lowerHint
        );
        LUSD.transfer(msg.sender, _LUSDAmount);
    }

    function adjustTrove(
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _LUSDChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable {
        require(msg.value == _collDeposit, "Invalid amount");

        if (_collDeposit > 0) {
            WETH.deposit{value: msg.value}();
        }
        if (!_isDebtIncrease && _LUSDChange > 0) {
            LUSD.transferFrom(msg.sender, address(this), _LUSDChange);
        }
        borrowerOperations.adjustTrove(
            msg.sender,
            _maxFeePercentage,
            _collDeposit,
            _collWithdrawal,
            _LUSDChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint
        );
        if (_collWithdrawal > 0) {
            WETH.withdraw(_collWithdrawal);
            msg.sender.transfer(_collWithdrawal);
        }
        if (_isDebtIncrease && _LUSDChange > 0) {
            LUSD.transfer(msg.sender, _LUSDChange);
        }
    }

    function closeTrove(uint256 _debt) external {
        LUSD.transferFrom(msg.sender, address(this), _debt);
        borrowerOperations.closeTrove(msg.sender);

        uint256 amount = WETH.balanceOf(address(this));
        WETH.withdraw(amount);
        msg.sender.transfer(amount);

        amount = LUSD.balanceOf(address(this));
        if (amount > 0) {
            LUSD.transfer(msg.sender, amount);
        }
    }

    function claimCollateral() external {
        borrowerOperations.claimCollateral(msg.sender);

        uint256 amount = WETH.balanceOf(address(this));
        WETH.withdraw(amount);
        msg.sender.transfer(amount);
    }
}
