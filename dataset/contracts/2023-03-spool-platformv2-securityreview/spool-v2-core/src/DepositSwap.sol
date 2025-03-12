// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./external/interfaces/weth/IWETH9.sol";
import "./interfaces/IAssetGroupRegistry.sol";
import "./interfaces/IDepositManager.sol";
import "./interfaces/IDepositSwap.sol";
import "./interfaces/ISmartVaultManager.sol";
import "./interfaces/ISwapper.sol";
import "./interfaces/CommonErrors.sol";

contract DepositSwap is IDepositSwap {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IWETH9 private immutable _weth;
    IAssetGroupRegistry private immutable _assetGroupRegistry;
    ISmartVaultManager private immutable _smartVaultManager;
    ISwapper private immutable _swapper;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IWETH9 weth_,
        IAssetGroupRegistry assetGroupRegistry_,
        ISmartVaultManager smartVaultManager_,
        ISwapper swapper_
    ) {
        _weth = weth_;
        _assetGroupRegistry = assetGroupRegistry_;
        _smartVaultManager = smartVaultManager_;
        _swapper = swapper_;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function swapAndDeposit(
        address[] calldata inTokens,
        uint256[] calldata inAmounts,
        SwapInfo[] calldata swapInfo,
        address smartVault,
        address receiver
    ) external payable returns (uint256) {
        if (inTokens.length != inAmounts.length) revert InvalidArrayLength();
        uint256 msgValue = msg.value;

        // Wrap eth if needed.
        if (msg.value > 0) {
            _weth.deposit{value: msgValue}();
        }

        // Transfer the tokens from the caller to the swapper.
        for (uint256 i; i < inTokens.length; ++i) {
            IERC20(inTokens[i]).safeTransferFrom(msg.sender, address(_swapper), inAmounts[i]);

            if (inTokens[i] == address(_weth) && msgValue > 0) {
                IERC20(address(_weth)).safeTransfer(address(_swapper), msgValue);
            }
        }

        uint256 nftId;
        {
            address[] memory outTokens = _assetGroupRegistry.listAssetGroup(_smartVaultManager.assetGroupId(smartVault));
            // Make the swap.
            _swapper.swap(inTokens, swapInfo, outTokens, address(this));
            uint256[] memory outAmounts = new uint256[](outTokens.length);
            // Figure out how much we got out of the swap.
            for (uint256 i; i < outTokens.length; ++i) {
                outAmounts[i] = IERC20(outTokens[i]).balanceOf(address(this));
                IERC20(outTokens[i]).safeApprove(address(_smartVaultManager), outAmounts[i]);
            }

            // Deposit into the smart vault.
            nftId = _smartVaultManager.deposit(DepositBag(smartVault, outAmounts, receiver, address(0), false));
        }

        // Return unswapped tokens.
        uint256 returnBalance;
        for (uint256 i; i < inTokens.length; ++i) {
            returnBalance = IERC20(inTokens[i]).balanceOf(address(this));
            if (returnBalance > 0) {
                IERC20(inTokens[i]).safeTransfer(msg.sender, returnBalance);
            }
        }
        if (msg.value > 0) {
            returnBalance = IERC20(address(_weth)).balanceOf(address(this));
            if (returnBalance > 0) {
                IERC20(address(_weth)).safeTransfer(msg.sender, returnBalance);
            }
        }

        // send back eth if swapper returns eth
        if (address(this).balance > 0) {
            payable(msg.sender).transfer(address(this).balance);
        }

        return nftId;
    }
}
