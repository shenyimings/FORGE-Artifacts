pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import './dependencies/token/ERC20/IERC20.sol';
import './dependencies/token/ERC20/SafeERC20.sol';
import './dependencies/math/SafeMath.sol';
import './interfaces/IAToken.sol';
import './interfaces/IFlashLoanReceiver.sol';

import {ILendingPool} from './interfaces/ILendingPool.sol';
import 'hardhat/console.sol';

contract AAVELendingPool {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    mapping(address => ILendingPool.ReserveData) internal _reserves;

    uint256 internal _flashLoanPremiumTotal = 9;

    constructor() {}

    // helper
    function addReserve(address underlyingAsset, address aToken) external {
        _reserves[underlyingAsset].aTokenAddress = aToken;
    }

    function deposit(
        address underlyingAsset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        address aToken = _reserves[underlyingAsset].aTokenAddress;
        IERC20(underlyingAsset).safeTransferFrom(msg.sender, aToken, amount);

        IAToken(aToken).mint(onBehalfOf, amount);
    }

    function simulateInterestIncrease(
        address underlyingAsset,
        address onBehalfOf,
        uint256 amount
    ) external {
        address aToken = _reserves[underlyingAsset].aTokenAddress;
        IAToken(aToken).mint(onBehalfOf, amount);
    }

    function withdraw(
        address underlyingAsset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        uint256 amountToWithdraw = amount;

        address aToken = _reserves[underlyingAsset].aTokenAddress;
        IAToken(aToken).burn(msg.sender, to, amountToWithdraw);

        return amountToWithdraw;
    }

    function getReserveData(address underlyingAsset) public view returns (ILendingPool.ReserveData memory) {
        return _reserves[underlyingAsset];
    }

    function FLASHLOAN_PREMIUM_TOTAL() public view returns (uint256) {
        return _flashLoanPremiumTotal;
    }

    struct FlashLoanLocalVars {
        IFlashLoanReceiver receiver;
        // address oracle;
        uint256 i;
        address currentAsset;
        address currentATokenAddress;
        uint256 currentAmount;
        uint256 currentPremium;
        uint256 currentAmountPlusPremium;
        // address debtToken;
    }

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external {
        FlashLoanLocalVars memory vars;

        address[] memory aTokenAddresses = new address[](assets.length);
        uint256[] memory premiums = new uint256[](assets.length);

        vars.receiver = IFlashLoanReceiver(receiverAddress);

        for (vars.i = 0; vars.i < assets.length; vars.i++) {
            aTokenAddresses[vars.i] = _reserves[assets[vars.i]].aTokenAddress;
            premiums[vars.i] = amounts[vars.i].mul(_flashLoanPremiumTotal).div(10000);
            IAToken(aTokenAddresses[vars.i]).transferUnderlyingTo(receiverAddress, amounts[vars.i]);
        }

        require(
            vars.receiver.executeOperation(assets, amounts, premiums, msg.sender, params),
            'LP_INVALID_FLASH_LOAN_EXECUTOR_RETURN'
        );

        for (vars.i = 0; vars.i < assets.length; vars.i++) {
            vars.currentAsset = assets[vars.i];
            vars.currentAmount = amounts[vars.i];
            vars.currentPremium = premiums[vars.i];
            vars.currentATokenAddress = aTokenAddresses[vars.i];
            vars.currentAmountPlusPremium = vars.currentAmount.add(vars.currentPremium);
            IERC20(vars.currentAsset).safeTransferFrom(receiverAddress, vars.currentATokenAddress, vars.currentAmountPlusPremium);
        }
    }
}
