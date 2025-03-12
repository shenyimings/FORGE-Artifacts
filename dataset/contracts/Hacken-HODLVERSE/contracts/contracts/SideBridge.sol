// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/IBridgeToken.sol";
import "./BasicBridge.sol";

contract SideBridge is BasicBridge {
    using SafeERC20 for IERC20;

    mapping(address => address) public swapMappingMainToSide;
    mapping(address => address) public swapMappingSideToMain;

    mapping(bytes32 => bool) public filledMainTx;

    event SwapPairCreated(address indexed bep20Addr, address indexed erc20Addr);
    event SwapStarted(
        address indexed bep20Addr,
        address indexed erc20Addr,
        address indexed fromAddr,
        uint256 amount,
        uint256 feeAmount
    );

    constructor(uint256 fee) public {
        swapFee = fee;
    }

    /**
     * @dev createSwapPair
     * @param mainERC20Addr token address from the parent chain
     * @param sideERC20Addr token address from the this chain
     */
    function createSwapPair(address mainERC20Addr, address sideERC20Addr)
        external
        onlyOwner
        returns (address)
    {
        require(
            swapMappingMainToSide[mainERC20Addr] == address(0x0),
            "SideBridge:createSwapPair:: ALREADY_REGISTERED"
        );

        swapMappingMainToSide[mainERC20Addr] = sideERC20Addr;
        swapMappingSideToMain[sideERC20Addr] = mainERC20Addr;

        emit SwapPairCreated(sideERC20Addr, mainERC20Addr);
        return sideERC20Addr;
    }

    /**
     * @dev fillMain2SideSwap
     */
    function fillMain2SideSwap(
        bytes32 txnHash,
        address token,
        address to,
        uint256 amount
    ) external onlyOwner returns (bool) {
        require(
            !filledMainTx[txnHash],
            "SideBridge:fillMain2SideSwap:: ALREADY_FILLED"
        );

        address sideTokenAddr = swapMappingMainToSide[token];
        require(
            sideTokenAddr != address(0x0),
            "SideBridge:fillMain2SideSwap:: TOKEN_NOT_REGISTERED"
        );

        filledMainTx[txnHash] = true;
        IBridgeToken(sideTokenAddr).mintTo(amount, to);

        emit SwapFilled(sideTokenAddr, txnHash, to, amount);
        return true;
    }

    /**
     * @dev swapSideToMain
     */
    function swapSideToMain(address token, uint256 amount)
        external
        payable
        returns (bool)
    {
        address erc20Addr = swapMappingSideToMain[token];
        require(
            erc20Addr != address(0x0),
            "SideBridge:swapSideToMain:: TOKEN_NOT_REGISTERED"
        );
        require(
            msg.value == swapFee,
            "SideBridge:swapSideToMain:: FEE_NOT_ENOUGH"
        );

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IBridgeToken(token).burn(amount);

        emit SwapStarted(token, erc20Addr, msg.sender, amount, msg.value);
        return true;
    }
}
