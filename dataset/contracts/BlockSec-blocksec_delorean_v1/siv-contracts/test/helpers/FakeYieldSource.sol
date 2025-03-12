//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/console.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { IFakeToken, FakeToken } from "./FakeToken.sol";
import { IYieldSource } from "../../src/interfaces/IYieldSource.sol";


contract CallbackFakeToken is FakeToken {
    address public callback;

    constructor(string memory name, string memory symbol, uint256 initialSupply, address callback_) FakeToken(name, symbol, initialSupply) {
        callback = callback_;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        FakeYieldSource(callback).callback(to);
        super._transfer(from, to, amount);
    }
}


contract FakeYieldSource is IYieldSource {
    using SafeERC20 for IERC20;

    uint256 public yieldPerBlock;
    uint256 public immutable startBlockNumber;
    uint256 public lastHarvestBlockNumber;
    uint256 public lastPendingBlockNumber;
    uint256 public pending;

    address public _yieldToken;
    IFakeToken public _generatorToken;
    address[] public holders;
    address public owner;
    bool public isWeth;

    constructor(uint256 yieldPerBlock_, address weth_) {
        startBlockNumber = block.number;
        yieldPerBlock = yieldPerBlock_;
        owner = msg.sender;

        isWeth = address(weth_) != address(0);
        if (isWeth) {
            _yieldToken = weth_;
        } else {
            _yieldToken = address(new FakeToken("TestYS: fake ETH", "fakeETH", 0));
        }
        _generatorToken = IFakeToken(new CallbackFakeToken("TestYS: fake GLP", "fakeGLP", 0, address(this)));
    }

    function yieldToken() external override view returns (IERC20) {
        return IERC20(_yieldToken);
    }

    function setYieldToken(address yieldToken_) external {
        _yieldToken = yieldToken_;
    }

    function generatorToken() external override view returns (IERC20) {
        return IERC20(_generatorToken);
    }

    function setGeneratorToken(address generatorToken_) external {
        _generatorToken = IFakeToken(generatorToken_);
    }

    function callback(address) public {
        checkpointPending();
    }

    function setOwner(address owner_) external override {
        owner = owner_;
    }

    function checkpointPending() public {
        pending += _pendingUnaccounted();
        lastPendingBlockNumber = block.number;
    }

    function setYieldPerBlock(uint256 yieldPerBlock_) public {
        checkpointPending();
        yieldPerBlock = yieldPerBlock_;
    }

    function mintBoth(address who, uint256 amount) public {
        mintGenerator(who, amount);
        mintYield(who, amount);
    }

    function mintGenerator(address who, uint256 amount) public {
        _generatorToken.publicMint(who, amount);
    }

    function mintYield(address who, uint256 amount) public {
        if (isWeth) {
            IERC20(_yieldToken).transfer(who, amount);
        } else {
            IFakeToken(_yieldToken).publicMint(who, amount);
        }
    }

    function harvest() public override {
        assert(owner != address(this));
        uint256 amount = this.amountPending();
        mintYield(address(this), amount);
        /* _yieldToken.publicMint(address(this), amount); */
        IERC20(_yieldToken).safeTransfer(owner, amount);
        lastHarvestBlockNumber = block.number;
        lastPendingBlockNumber = block.number;
        pending = 0;
    }

    function _pendingUnaccounted() internal view returns (uint256) {
        uint256 start = lastPendingBlockNumber == 0 ? startBlockNumber : lastPendingBlockNumber;
        uint256 deltaBlocks = block.number - start;
        return _generatorToken.balanceOf(address(this)) * deltaBlocks * yieldPerBlock;
    }

    function amountPending() external override virtual view returns (uint256) {
        return _pendingUnaccounted() + pending;
    }

    function deposit(uint256 amount, bool claim) external override {
        IERC20(_generatorToken).safeTransferFrom(msg.sender, address(this), amount);

        if (claim) this.harvest();
    }

    function withdraw(uint256 amount, bool claim, address to) external override {
        checkpointPending();

        uint256 balance = _generatorToken.balanceOf(address(this));
        if (amount > balance) {
            amount = balance;
        }
        IERC20(_generatorToken).safeTransfer(to, amount);
        if (claim) this.harvest();
    }

    function amountGenerator() external override view returns (uint256) {
        return _generatorToken.balanceOf(address(this));
    }
}
