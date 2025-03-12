// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

struct BatchSwapStep {
    bytes32 poolId;
    uint256 assetInIndex;
    uint256 assetOutIndex;
    uint256 amount;
    bytes userData;
}

enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
}

struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    IAsset assetIn;
    IAsset assetOut;
    uint256 amount;
    bytes userData;
}

struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
}

interface IAsset {
    // solhint-disable-previous-line no-empty-blocks
}

interface IBalancer {
    function batchSwap(
        uint8 kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external returns (int256[] memory assetDeltas);

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256);
}

contract BalancerTest {
    address balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address note = 0xCFEAead4947f0705A14ec42aC3D44129E1Ef3eD5;
    address zero = 0x0000000000000000000000000000000000000000;
    bytes32 poolId = 0xe7b1d394f3b40abeaa0b64a545dbcf89da1ecb3f00010000000000000000009a;

    receive() external payable {}

    function swapUSDC(uint256 _amount) public payable {
        // Create SingleSwap structure
        SingleSwap memory singleSwap = SingleSwap({
            poolId: poolId,
            assetIn: IAsset(zero),
            assetOut: IAsset(usdc),
            kind: SwapKind.GIVEN_IN,
            amount: _amount,
            userData: ""
        });

        // Create fund structure
        FundManagement memory funds = FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        uint256 limit = 0;

        IBalancer(balancer).swap{value: _amount}(singleSwap, funds, limit, block.timestamp + 3600);

        console.log("USDC: ", IERC20(usdc).balanceOf(address(this)));
    }
}
