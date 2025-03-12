// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/*
 ██████╗ █████╗ ██╗   ██╗██╗        ██████╗ █████╗ ██╗     ██╗██████╗ ██╗████████╗██╗   ██╗
██╔════╝██╔══██╗██║   ██║██║       ██╔════╝██╔══██╗██║     ██║██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝
╚█████╗ ██║  ██║██║   ██║██║       ╚█████╗ ██║  ██║██║     ██║██║  ██║██║   ██║    ╚████╔╝ 
 ╚═══██╗██║  ██║██║   ██║██║        ╚═══██╗██║  ██║██║     ██║██║  ██║██║   ██║     ╚██╔╝  
██████╔╝╚█████╔╝╚██████╔╝███████╗  ██████╔╝╚█████╔╝███████╗██║██████╔╝██║   ██║      ██║   
╚═════╝  ╚════╝  ╚═════╝ ╚══════╝  ╚═════╝  ╚════╝ ╚══════╝╚═╝╚═════╝ ╚═╝   ╚═╝      ╚═╝   

 * Twitter: https://twitter.com/SoulSolidity
 *  GitHub: https://github.com/SoulSolidity
 *     Web: https://SoulSolidity.com
 */

// External package imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

// Internal route directory imports
import {ISoulFeeManager} from "../fee-manager/ISoulFeeManager.sol";
import {SoulZap_UniV2_Lens} from "../SoulZap_UniV2_Lens.sol";
import {SoulZap_UniV2} from "../SoulZap_UniV2.sol";
import {SoulZap_Ext_ApeBond_Lens} from "../extensions/ApeBond/SoulZap_Ext_ApeBond_Lens.sol";

/**
 * @title SoulZap_UniV2_Extended_V1
 * @dev This contract is an implementation of ISoulZap interface. It includes functionalities for zapping in and out of
 * UniswapV2 type liquidity pools.
 * @notice This contract has the following features:
 * 1. UniswapV2 Zap In
 * 2. Deposit into ApeBond, Bond contracts.
 * @author Soul Solidity - Contact for mainnet licensing until 730 days after first deployment transaction with matching bytecode.
 * Otherwise feel free to experiment locally or on testnets.
 */
contract SoulZap_UniV2_Extended_V1_Lens is SoulZap_UniV2_Lens, SoulZap_Ext_ApeBond_Lens {
    constructor(
        SoulZap_UniV2 _soulZap,
        IUniswapV2Router02 _router,
        address[] memory _hopTokens
    ) SoulZap_UniV2_Lens(_soulZap, _router, _hopTokens) SoulZap_Ext_ApeBond_Lens() {}
}
