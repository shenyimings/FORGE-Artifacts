// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Context.sol';

import '../dependencies/uniswap-v2/IUniswapV2Router02.sol';
import '../interfaces/IOpenSkySettings.sol';
import '../interfaces/IACLManager.sol';

import '../interfaces/IOpenSkyDaoVaultUniswapV2Adapter.sol';

/**
 * @dev Provide swap services for OpenSkyDaoVault contract.
 * - OpenSkyDaoVault should approve 'amount' of 'token' to this contract first
 * - Receiver of swap is always OpenSkyDaoVault
 * - Only callable by governance
 */
contract OpenSkyDaoVaultUniswapV2Adapter is Context, IOpenSkyDaoVaultUniswapV2Adapter {
    using SafeERC20 for IERC20;

    IOpenSkySettings public immutable SETTINGS;
    address public immutable WETH_ADDRESS;
    address public immutable DAO_VAULT_ADDRESS;
    IUniswapV2Router02 public immutable UNISWAP_ROUTER;

    modifier onlyGovernance() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isGovernance(_msgSender()), 'ACL_ONLY_GOVERNANCE_CAN_CALL');
        _;
    }

    constructor(
        address settingsAddress,
        address daoVaultAddress,
        address uniswapRouterAddress,
        address wethAddress
    ) {
        SETTINGS = IOpenSkySettings(settingsAddress);
        DAO_VAULT_ADDRESS = daoVaultAddress;
        UNISWAP_ROUTER = IUniswapV2Router02(uniswapRouterAddress);
        WETH_ADDRESS = wethAddress;
    }

    function pullERC20FromDaoVault(address token, uint256 amount) public onlyGovernance {
        IERC20(token).safeTransferFrom(DAO_VAULT_ADDRESS, address(this), amount);
    }

    function swapExactTokensForTokens(
        address assetToSwapFrom,
        address assetToSwapTo,
        uint256 amountToSwap,
        uint256 minAmountOut,
        bool useEthPath
    ) external onlyGovernance returns (uint256) {
        // step1: pull asset
        pullERC20FromDaoVault(assetToSwapFrom, amountToSwap);

        // step2: approve
        IERC20(assetToSwapFrom).safeApprove(address(UNISWAP_ROUTER), 0);
        IERC20(assetToSwapFrom).safeApprove(address(UNISWAP_ROUTER), amountToSwap);

        // step3: swap
        address[] memory path;
        if (useEthPath) {
            path = new address[](3);
            path[0] = assetToSwapFrom;
            path[1] = WETH_ADDRESS;
            path[2] = assetToSwapTo;
        } else {
            path = new address[](2);
            path[0] = assetToSwapFrom;
            path[1] = assetToSwapTo;
        }

        uint256[] memory amounts = UNISWAP_ROUTER.swapExactTokensForTokens(
            amountToSwap,
            minAmountOut,
            path,
            DAO_VAULT_ADDRESS,
            block.timestamp
        );

        emit Swapped(assetToSwapFrom, assetToSwapTo, amounts[0], amounts[amounts.length - 1]);

        return amounts[amounts.length - 1];
    }

    function swapTokensForExactTokens(
        address assetToSwapFrom,
        address assetToSwapTo,
        uint256 maxAmountToSwap,
        uint256 amountToReceive,
        bool useEthPath
    ) external onlyGovernance returns (uint256) {
        // step1 pull asset
        pullERC20FromDaoVault(assetToSwapFrom, maxAmountToSwap);

        // step2: approve
        IERC20(assetToSwapFrom).safeApprove(address(UNISWAP_ROUTER), 0);
        IERC20(assetToSwapFrom).safeApprove(address(UNISWAP_ROUTER), maxAmountToSwap);

        // step3: swap
        address[] memory path;
        if (useEthPath) {
            path = new address[](3);
            path[0] = assetToSwapFrom;
            path[1] = WETH_ADDRESS;
            path[2] = assetToSwapTo;
        } else {
            path = new address[](2);
            path[0] = assetToSwapFrom;
            path[1] = assetToSwapTo;
        }

        uint256[] memory amounts = UNISWAP_ROUTER.swapTokensForExactTokens(
            amountToReceive,
            maxAmountToSwap,
            path,
            DAO_VAULT_ADDRESS,
            block.timestamp
        );

        emit Swapped(assetToSwapFrom, assetToSwapTo, amounts[0], amounts[amounts.length - 1]);

        return amounts[0];
    }

    /**
     * @dev Emergency rescue for token stuck on this contract, as failsafe mechanism
     * - Funds should never remain in this contract more time than during transactions
     * - Only callable by governance
     **/
    function rescueTokens(IERC20 token) external onlyGovernance {
        token.safeTransfer(DAO_VAULT_ADDRESS, token.balanceOf(address(this)));
    }
}
