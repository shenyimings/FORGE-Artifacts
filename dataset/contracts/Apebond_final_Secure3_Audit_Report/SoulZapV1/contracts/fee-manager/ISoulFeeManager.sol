// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

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

/**
 * @title SoulFeeManager_Interface
 * @dev This contract is an interface for the SoulFeeManager. It includes a function for getting the fee based on epoch volume.
 * @author Soul Solidity - Contact for mainnet licensing until 730 days after first deployment transaction with matching bytecode.
 * Otherwise feel free to experiment locally or on testnets.
 */
interface ISoulFeeManager {
    function isSoulFeeManager() external view returns (bool);

    function FEE_DENOMINATOR() external view returns (uint256 denominator);

    function getFeeInfo(
        uint256 _volume
    )
        external
        view
        returns (
            address[] memory feeTokens,
            uint256 currentFeePercentage,
            uint256 feeDenominator,
            address feeCollector
        );

    function getFee(uint256 epochVolume) external view returns (uint256 fee);

    function getFeeCollector() external view returns (address fee);

    function getFeeTokensLength() external view returns (uint256 length);

    function getFeeTokens() external view returns (address[] memory tokens);

    function getFeeToken(uint256 index) external view returns (address token);

    function isFeeToken(address _token) external view returns (bool valid);
}
