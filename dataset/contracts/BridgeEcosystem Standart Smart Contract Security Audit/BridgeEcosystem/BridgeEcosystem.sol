// SPDX-License-Identifier: MIT

import "IBridgeEcosystem.sol";
import "Context.sol";
import "SafeOperatable.sol";
import {ISwapRouterV2} from "ISwapV2.sol";

pragma solidity ^0.8.5;

contract BridgeEcosystem is SafeOperatable, IBridgeEcosystem {
    mapping(address => Token) private _tokens;
    address[] private _tokenStorage;
    uint256 private _lastDistribute;
    bool private _inDistribute;

    event Receive(address indexed from, uint256 amount);
    event Fallback(uint256 amount);
    event BuyBurn(address indexed from, uint256 amount);
    event BuyBurnError(address indexed from, uint256 amount, string reason);
    event BuyBurnError(address indexed from, uint256 amount, bytes reason);
    event TokenAdded(address token);
    event TokenRemoved(address token);

    struct Token {
        bool contains;
        uint256 index;
        ISwapRouterV2 swapRouter;
        address[] swapPath;
    }

    modifier lockDistribute {
        _inDistribute = true;
        _;
        _inDistribute = false;
    }

    constructor(address otherOperator, address backupOperator, uint256 initialVotes) SafeOperatable(otherOperator, backupOperator, initialVotes) {}

    fallback() external payable {
        emit Fallback(msg.value);
    }

    receive() external payable {
        emit Receive(_msgSender(), msg.value);

        if (_lastDistribute + 1 minutes <= block.timestamp && !_inDistribute) {
            _lastDistribute = block.timestamp;
            _distribute();
        }
    }

    function _distribute() private lockDistribute {
        uint256 balance = address(this).balance;
        uint256 shareAmount = balance / _tokenStorage.length;

        for (uint256 i = 0; i < _tokenStorage.length; i++) {
            address tokenAddress = _tokenStorage[i];
            Token memory token = _tokens[tokenAddress];
            try token.swapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
                    value: shareAmount
                }(0, token.swapPath, address(this), block.timestamp) {
                emit BuyBurn(tokenAddress, shareAmount);
            }
            catch Error(string memory reason) {
                emit BuyBurnError(tokenAddress, shareAmount, reason);
            }
            catch (bytes memory reason) {
                emit BuyBurnError(tokenAddress, shareAmount, reason);
            }
        }
    }

    function add(address token, address swapRouter) public onlyOperator {
        require(!isWhitelisted(token), "BECO: Token is exists");

        _tokenStorage.push(token);
        _tokens[token].contains = true;
        _tokens[token].index = _tokenStorage.length - 1;
        _tokens[token].swapRouter = ISwapRouterV2(swapRouter);
        _tokens[token].swapPath = [_tokens[token].swapRouter.WETH(), token];

        emit TokenAdded(token);
    }

    function remove(address token) public onlyOperator {
        require(isWhitelisted(token), "BECO: Token is not exists");
        
        _tokens[_tokenStorage[_tokenStorage.length - 1]].index = _tokens[token].index;
        _tokenStorage[_tokens[token].index] = _tokenStorage[_tokenStorage.length - 1];
        _tokenStorage.pop();
        _tokens[token].contains = false;
        emit TokenRemoved(token);
    }

    function isWhitelisted(address token) public view override returns (bool) {
        return _tokens[token].contains;
    }
}
