// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../Interfaces/IEUSDToken.sol";

contract EUSDTokenCaller {
    IEUSDToken EUSD;

    function setEUSD(IEUSDToken _EUSD) external {
        EUSD = _EUSD;
    }

    function eusdMint(address _account, uint256 _amount) external {
        EUSD.mint(_account, _amount);
    }

    function eusdBurn(address _account, uint256 _amount) external {
        EUSD.burn(_account, _amount);
    }

    function eusdSendToPool(
        address _sender,
        address _poolAddress,
        uint256 _amount
    ) external {
        EUSD.sendToPool(_sender, _poolAddress, _amount);
    }

    function eusdReturnFromPool(
        address _poolAddress,
        address _receiver,
        uint256 _amount
    ) external {
        EUSD.returnFromPool(_poolAddress, _receiver, _amount);
    }
}
