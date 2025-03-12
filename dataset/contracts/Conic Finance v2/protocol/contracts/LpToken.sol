// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IController.sol";
import "../interfaces/pools/ILpToken.sol";

contract LpToken is ILpToken, ERC20 {
    IController public immutable controller;

    address public immutable minter;

    modifier onlyMinter() {
        require(msg.sender == minter, "not authorized");
        _;
    }

    mapping(address => uint256) internal _lastEvent;

    uint8 private __decimals;

    constructor(
        address _controller,
        address _minter,
        uint8 _decimals,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        controller = IController(_controller);
        minter = _minter;
        __decimals = _decimals;
    }

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return __decimals;
    }

    function mint(
        address _account,
        uint256 _amount,
        address ubo
    ) external override onlyMinter returns (uint256) {
        _ensureSingleEvent(ubo, _amount);
        _mint(_account, _amount);
        return _amount;
    }

    function burn(
        address _owner,
        uint256 _amount,
        address ubo
    ) external override onlyMinter returns (uint256) {
        _ensureSingleEvent(ubo, _amount);
        _burn(_owner, _amount);
        return _amount;
    }

    function taint(address from, address to) external {
        require(msg.sender == address(controller.lpTokenStaker()), "not authorized");
        _taint(from, to);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        // mint/burn are handled in their respective functions
        if (from == address(0) || to == address(0)) return;

        // lpTokenStaker calls `taint` as needed
        address lpTokenStaker = address(controller.lpTokenStaker());
        if (from == lpTokenStaker || to == lpTokenStaker) return;

        // taint any other type of transfer
        if (amount > controller.getMinimumTaintedTransferAmount(address(this))) {
            _taint(from, to);
        }
    }

    function _ensureSingleEvent(address ubo, uint256 amount) internal {
        if (
            !controller.isAllowedMultipleDepositsWithdraws(ubo) &&
            amount > controller.getMinimumTaintedTransferAmount(address(this))
        ) {
            require(_lastEvent[ubo] != block.number, "cannot mint/burn twice in a block");
            _lastEvent[ubo] = block.number;
        }
    }

    function _taint(address from, address to) internal {
        if (from == to) return;
        if (_lastEvent[from] == block.number) {
            _lastEvent[to] = block.number;
        }
    }
}
