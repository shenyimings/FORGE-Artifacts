// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./CrosschainERC20.sol";

interface WrappedCoin {
    function deposit() external payable;

    function withdraw(uint256) external;
}

contract CrosschainCoinRouter {
    using SafeERC20 for ERC20;

    WrappedCoin public wrappedCoin;
    CrosschainERC20 public cerc20;

    constructor(CrosschainERC20 _cerc20) {
        ERC20 ct = _cerc20.coToken();
        cerc20 = _cerc20;
        ct.safeApprove(address(cerc20), type(uint256).max);
        wrappedCoin = WrappedCoin(address(ct));
    }

    receive() external payable {}

    function resetAllowance() public {
        ERC20 wc = ERC20(address(wrappedCoin));
        uint256 allowance = wc.allowance(address(this), address(cerc20));
        if (allowance != type(uint256).max) {
            wc.safeIncreaseAllowance(address(cerc20), type(uint256).max - allowance);
        }
    }

    function swapCoinForCrosschainCoin(uint256 _amount) public payable {
        require(msg.value == _amount, "incorrect amount value");
        wrappedCoin.deposit{value: _amount}();
        cerc20.depositTo(msg.sender, _amount);
    }

    function swapCrosschainCoinForCoin(uint256 _amount) public {
        ERC20(cerc20).safeTransferFrom(msg.sender, address(this), _amount);
        cerc20.withdraw(_amount);
        wrappedCoin.withdraw(_amount);
        payable(msg.sender).transfer(_amount);
    }

    function swapWrappedCoinForCrosschainCoin(uint256 _amount) public {
        ERC20(address(wrappedCoin)).safeTransferFrom(msg.sender, address(this), _amount);
        cerc20.depositTo(msg.sender, _amount);
    }

    function swapCrosschainCoinForWrappedCoin(uint256 _amount) public {
        ERC20(cerc20).safeTransferFrom(msg.sender, address(this), _amount);
        cerc20.withdrawTo(msg.sender, _amount);
    }

    function swapCoinForWrappedCoin(uint256 _amount) public payable {
        require(msg.value == _amount, "incorrect amount value");
        wrappedCoin.deposit{value: _amount}();
        ERC20(address(wrappedCoin)).safeTransfer(msg.sender, _amount);
    }

    function swapWrappedCoinForCoin(uint256 _amount) public {
        ERC20(address(wrappedCoin)).safeTransferFrom(msg.sender, address(this), _amount);
        wrappedCoin.withdraw(_amount);
        payable(msg.sender).transfer(_amount);
    }
}
