// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./MockERC20.sol";
import "../interface/IAlpacaVault.sol";
import "hardhat/console.sol";

contract MockAlpacaVault is MockERC20("Alpaca Vault", "VAULT"), IAlpacaVault {
    IERC20 public token;
    uint256 public _totalToken;

    constructor(IERC20 _token) public {
        token = _token;
    }

    function totalToken() public view override returns (uint256) {
        return _totalToken;
    }

    function deposit(uint256 amountToken) external payable override {
        if (amountToken > 0) {
            _totalToken += amountToken;
            uint256 total = totalToken() - amountToken;
            uint256 share = total == 0 ? amountToken : (amountToken * totalSupply()) / total;
            _mint(msg.sender, share);
            token.transferFrom(msg.sender, address(this), amountToken);
        }
    }

    function withdraw(uint256 share) external override {
        if (share > 0 && totalToken() > 0 && totalSupply() > 0) {
            uint256 amount = (share * totalToken()) / totalSupply();
            _totalToken -= amount;
            _burn(msg.sender, share);
            token.transfer(msg.sender, amount);
        }
    }

    function addTotalToken(uint256 _addToken) external {
        _totalToken += _addToken;
    }
}
