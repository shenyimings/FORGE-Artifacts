// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {MockERC20} from "./MockERC20.sol";
import {WETH} from "./WETH.sol";

/* solhint-disable no-empty-blocks */

struct Token {
    uint256 amount;
    address token;
}

contract Multisender {
    mapping(address => bool) public owners;
    mapping(address => bool) public funded;

    Token[] internal tokens;
    WETH internal weth;
    address internal kiss;

    event Funded(address indexed account);

    constructor(Token[] memory _tokens, address _weth, address _kiss) {
        owners[msg.sender] = true;

        for (uint256 i; i < _tokens.length; i++) {
            tokens.push(_tokens[i]);
        }
        weth = WETH(_weth);
        kiss = _kiss;
    }

    function addToken(Token memory _token) external {
        require(owners[msg.sender], "!o");
        tokens.push(_token);
    }

    function setTokens(Token[] memory _tokens) external {
        require(owners[msg.sender], "!o");
        for (uint256 i; i < _tokens.length; i++) {
            tokens[i].amount = _tokens[i].amount;
            tokens[i].token = _tokens[i].token;
        }
    }

    function toggleOwners(address[] calldata accounts) external {
        require(owners[msg.sender], "!o");
        for (uint256 i; i < accounts.length; i++) {
            owners[accounts[i]] = !owners[accounts[i]];
        }
    }

    function distribute(
        address[] calldata accounts,
        uint256 wethAmount,
        uint256 ethAmount,
        uint256 kissAmount
    ) external {
        require(owners[msg.sender], "!o");
        for (uint256 i; i < accounts.length; i++) {
            if (funded[accounts[i]]) continue;

            funded[accounts[i]] = true;
            for (uint256 j; j < tokens.length; j++) {
                MockERC20(tokens[j].token).mint(accounts[i], tokens[j].amount);
            }

            weth.deposit(wethAmount);
            weth.transfer(accounts[i], wethAmount);
            MockERC20(kiss).transfer(accounts[i], kissAmount);

            payable(accounts[i]).transfer(ethAmount);

            emit Funded(accounts[i]);
        }
    }

    function drain() external {
        require(owners[msg.sender], "!o");
        payable(msg.sender).transfer(address(this).balance);
    }

    function drainERC20() external {
        require(owners[msg.sender], "!o");
        MockERC20(kiss).transfer(msg.sender, MockERC20(kiss).balanceOf(address(this)));
    }

    receive() external payable {}

    fallback() external payable {}
}
