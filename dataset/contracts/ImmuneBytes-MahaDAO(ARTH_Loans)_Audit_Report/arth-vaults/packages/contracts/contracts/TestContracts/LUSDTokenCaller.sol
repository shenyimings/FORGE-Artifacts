// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../Interfaces/ILUSDToken.sol";
import "../Interfaces/IController.sol";

contract LUSDTokenCaller {
    ILUSDToken LUSD;
    IController controller;

    function setLUSD(ILUSDToken _LUSD, IController _controller) external {
        LUSD = _LUSD;
        controller = _controller;
    }

    function lusdMint(address _account, uint256 _amount) external {
        LUSD.poolMint(_account, _amount);
    }

    function lusdBurn(address _account, uint256 _amount) external {
        LUSD.poolBurnFrom(_account, _amount);
    }

    function lusdSendToPool(
        address _sender,
        address _poolAddress,
        uint256 _amount
    ) external {
        controller.sendToPool(_sender, _poolAddress, _amount);
    }

    // function lusdReturnFromPool(address _poolAddress, address _receiver, uint256 _amount ) external {
    //     LUSD.returnFromPool(_poolAddress, _receiver, _amount);
    // }
}
