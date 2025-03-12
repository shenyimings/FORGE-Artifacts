// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import "./FlashLoanReceiverBase.sol";
import "../Interfaces/ITroveManager.sol";
import "../Interfaces/IBorrowerOperations.sol";
import "../Dependencies/IUniswapV2Router02.sol";
import "../Dependencies/ILendingPool.sol";
import "../Dependencies/SafeMath.sol";
import "../Dependencies/IERC20.sol";
import "../Dependencies/ILendingPool.sol";

contract Leverage is FlashLoanReceiverBase {
    using SafeMath for uint256;
    
    IUniswapV2Router02 public router;
    ITroveManager public troveManager;
    IBorrowerOperations public borrowerOperations;
    ILendingPool public lendingPool;

    // Because there might not be direct pair between `USDC to Collateral`. 
    // (Since we are swapping from LUSD to USDC and then to collateral).
    address[] public lusdToCollateralSwapPath;

    struct LeverageAndTroveDetails {
        uint256 ownerCollAmount;  // Collateral amount given by owner.
        uint256 loanedCollAmount;  // Collateral amount taken as loan.
        uint256 totalCollAmount;  // Total position collateral amount.
        uint256 maxFee;
        address upperHint;
        address lowerHint;
        uint256 totalLusdAmount;  // LUSD to be minted after leverage collateral is given.
    }

    event FlashLoanInitiated(address from, uint256 amount, uint256 timestamp);

    constructor(
        IUniswapV2Router02 _router,
        ILendingPoolAddressesProvider _lendingPoolAddressProvider,
        IBorrowerOperations _borrowerOperations,
        ITroveManager _troveManager,
        address[] memory _lusdToCollateralSwapPath
    ) 
        FlashLoanReceiverBase(_lendingPoolAddressProvider) 
        public 
    {   
        lendingPool = ILendingPool(
            _lendingPoolAddressProvider.getLendingPool()
        );

        lusdToCollateralSwapPath = _lusdToCollateralSwapPath;
        router = _router;
        troveManager = _troveManager;
        borrowerOperations = _borrowerOperations;
    }

    function flashloan(
        uint256 ownerCollAmount,
        uint256 loanedCollAmount, 
        uint256 maxFee,
        address upperHint,
        address lowerHint,
        uint256 totalLusdAmount  // LUSD minted after givin ownerCollAmount + loanedCollAmount.
    ) external {
        LeverageAndTroveDetails memory troveDetails = LeverageAndTroveDetails(
            ownerCollAmount, 
            loanedCollAmount,
            ownerCollAmount.add(loanedCollAmount),
            maxFee, 
            upperHint, 
            lowerHint,
            totalLusdAmount
        );
        
        bytes memory paramsData = abi.encode(troveDetails);
        address collateralAddress = lusdToCollateralSwapPath[lusdToCollateralSwapPath.length -  1];
        
        lendingPool.flashLoan(address(this), collateralAddress, loanedCollAmount, paramsData);

        emit FlashLoanInitiated(msg.sender, loanedCollAmount, block.timestamp);
    }

    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    )
        external 
        override 
    {
        // 1. Check the contract has the specified balance.
        require(
            _amount <= getBalanceInternal(address(this), _reserve),
            "Leverage: Invalid balance for the contract"
        );
        
        // 2. Decode the data passed as input to flashloan.
        LeverageAndTroveDetails memory troveDetails = abi.decode(_params, (LeverageAndTroveDetails));

        // 3. Open a trove.
        uint256 lusdMinted = _openTrove(_reserve, troveDetails, _fee, tx.origin);

        // 4. Swap LUSD for Collateral.
        uint256 swappedAmount = _swapLUSDForCollateral(lusdMinted);
        // 5. Check that the swapped amount is atleast equal to that required to complete flashloan.
        require(swappedAmount >= _amount.add(_fee));

        // 6. Transfer the funds back to aave with fee.
        transferFundsBackToPoolInternal(_reserve, _amount.add(_fee));

        // 7-A. If there is some eth left (0x fee), return it to user
        if (_reserve == EthAddressLib.ethAddress() && address(this).balance > 0) {
            tx.origin.transfer(address(this).balance);
        }

        // 7-B. If there is some collateral left (0x fee), return it to user
        if (_reserve != EthAddressLib.ethAddress() && IERC20(_reserve).balanceOf(address(this)) > 0) {
            IERC20(_reserve).transfer(
                tx.origin, 
                IERC20(_reserve).balanceOf(address(this))
            );
        }

        // 8. Finally if everything is successful move the trove.
        _moveTrove(tx.origin);
    }

    function _swapLUSDForCollateral(uint256 _LUSDAmount) internal returns (uint256) {
        // 1. Get the expected out amounts.
        uint256[] memory expectedAmountsOut = router.getAmountsOut(_LUSDAmount, lusdToCollateralSwapPath);
        uint256 expectedAmountOutMin =  expectedAmountsOut[expectedAmountsOut.length - 1];

        // 2. Approve the router and swap LUSD for collateral.
        IERC20(lusdToCollateralSwapPath[0]).approve(address(router), _LUSDAmount);
        uint256[] memory amountsOut = router.swapExactTokensForTokens(
            _LUSDAmount,
            expectedAmountOutMin,
            lusdToCollateralSwapPath,
            address(this),
            block.timestamp
        );

        // 3. Verify that we receive atleast the expected collateral.
        uint256 amountOut = amountsOut[amountsOut.length - 1];
        require(amountOut >= expectedAmountOutMin, "Leverage: Slippage while swap");

        return amountOut;
    }

    function _openTrove(
        address _reserve,
        LeverageAndTroveDetails memory troveDetails,
        uint256 _fee,
        address _collateralOwner
    ) internal returns (uint256) {
        // 1. Transfer the collateral fund from `tx.origin` to this address.
        IERC20(_reserve).transferFrom(_collateralOwner, address(this), troveDetails.ownerCollAmount);

        // 2. Get the amount of LUSD that should be minted to cover fee.
        uint256[] memory expectedAmountsIn = router.getAmountsIn(_fee, lusdToCollateralSwapPath);
        uint256 expectedLUSDMintToCoverFee = expectedAmountsIn[0];

        // 3. Note the balance of LUSD before opening a trove.
        uint256 lusdBalanceBefore = IERC20(lusdToCollateralSwapPath[0]).balanceOf(address(this));

        // 4. Should mint for `owner collateral` + `loaned collateral` + `loan fee collateral`.
        uint256 expectedTotalLUSDMint = troveDetails.totalLusdAmount.add(expectedLUSDMintToCoverFee);
        // 5. Open the trove with leverage.
        borrowerOperations.openTrove(
            troveDetails.maxFee,
            expectedTotalLUSDMint,
            troveDetails.totalCollAmount,
            troveDetails.upperHint, 
            troveDetails.lowerHint
        );

        // 5. Note the balance of LUSD after opening the trove.
        uint256 lusdBalanceAfter = IERC20(
            lusdToCollateralSwapPath[0]).balanceOf(address(this)
        );

        // 6. Return the amount of LUSD minted.
        uint256 lusdMinted = lusdBalanceAfter.sub(lusdBalanceBefore);

        // 7. Check that expected LUSD is minted.
        require(
           lusdMinted >= expectedTotalLUSDMint,
           "Leverage: Slippage while opening trove"
        );

       return lusdMinted;
    }

    function _moveTrove(
        address newOwner
    ) internal {
        troveManager.moveTrove(newOwner);
    }
}