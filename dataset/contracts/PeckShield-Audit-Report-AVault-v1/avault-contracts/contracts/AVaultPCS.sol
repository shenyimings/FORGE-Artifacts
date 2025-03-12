// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./AVaultBase.sol";

contract AVaultPCS is AVaultBase {
    constructor(
        address[] memory _addresses,
        uint256 _pid,
        bool _isCAKEStaking,
        address[] memory _earnedToWethPath,
        address[] memory _wethToAVAPath,
        address[] memory _earnedToToken0Path,
        address[] memory _earnedToToken1Path,
        address[] memory _token0ToEarnedPath,
        address[] memory _token1ToEarnedPath,
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC20(_tokenName, _tokenSymbol) {
        wethAddress = _wethToAVAPath[0];
        AVAAddress = _wethToAVAPath[_wethToAVAPath.length - 1];
        wantAddress = _addresses[0];
        token0Address = _token0ToEarnedPath[0];
        token1Address = _token1ToEarnedPath[0];
        earnedAddress = _earnedToToken0Path[0];

        farmContractAddress = _addresses[1];
        pid = _pid;
        isCAKEStaking = _isCAKEStaking;

        uniRouterAddress = _addresses[2];
        wethToAvaRouterAddress = _addresses[3];
        
        earnedToWethPath = _earnedToWethPath;
        wethToAVAPath = _wethToAVAPath;
        earnedToToken0Path = _earnedToToken0Path;
        earnedToToken1Path = _earnedToToken1Path;
        token0ToEarnedPath = _token0ToEarnedPath;
        token1ToEarnedPath = _token1ToEarnedPath;

        buyBackAddress = IDistributable(_addresses[4]);
    }
}
