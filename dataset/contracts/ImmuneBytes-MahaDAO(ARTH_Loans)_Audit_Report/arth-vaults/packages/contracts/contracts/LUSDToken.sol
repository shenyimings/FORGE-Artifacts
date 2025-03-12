// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import {ILUSDToken} from "./Interfaces/ILUSDToken.sol";
import {IARTHController} from "./Dependencies/IARTHController.sol";
import {IERC20} from "./Dependencies/IERC20.sol";
import {ARTHERC20Custom} from "./Dependencies/ARTHERC20Custom.sol";
import {SafeMath} from "./Dependencies/SafeMath.sol";
import {IAnyswapV4Token} from "./Dependencies/IAnyswapV4Token.sol";
import {AnyswapV4Token} from "./Dependencies/AnyswapV4Token.sol";

/**
 * @title  ARTHStablecoin.
 * @author MahaDAO.
 */
contract LUSDToken is AnyswapV4Token, ILUSDToken {
    using SafeMath for uint256;

    // bytes32 public constant GOVERNANCE_ROLE = keccak256('GOVERNANCE_ROLE');
    // bytes32 public constant OWNERSHIP_ROLE = keccak256('GOVERNANCE_ROLE');

    address public governance;
    IARTHController public controller;

    uint8 public constant override decimals = 18;
    string public constant override symbol = "ARTH";
    string public constant override name = "ARTH Valuecoin";
    bool public allowRebase = true;

    /// @dev ARTH v1 already in circulation.
    uint256 private INITIAL_AMOUNT_SUPPLY = 25_000_000 ether;
    uint256 public gonsPerFragment = 1e6;

    event Rebase(uint256 supply);
    event PoolBurned(address indexed from, address indexed to, uint256 amount);
    event PoolMinted(address indexed from, address indexed to, uint256 amount);

    modifier onlyPools() {
        require(controller.isPool(msg.sender), "ARTH: not an approved pool");
        _;
    }

    modifier onlyByOwnerOrGovernance() {
        require(msg.sender == owner() || msg.sender == governance, "ARTH: not owner or governance");
        _;
    }

    modifier requireValidRecipient(address _recipient) {
        require(
            _recipient != address(0) && _recipient != address(this),
            "ARTH: Cannot transfer tokens directly to the ARTH token contract or the zero address"
        );
        _;
    }

    constructor() public AnyswapV4Token(name) {
        // _mint(_msgSender(), INITIAL_AMOUNT_SUPPLY);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function transferAndCall(
        address to,
        uint256 value,
        bytes calldata data
    ) public override(IAnyswapV4Token, AnyswapV4Token) requireValidRecipient(to) returns (bool) {
        return super.transferAndCall(to, value, data);
    }

    function transferWithPermit(
        address target,
        address to,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override(IAnyswapV4Token, AnyswapV4Token) requireValidRecipient(to) returns (bool) {
        return super.transferWithPermit(target, to, value, deadline, v, r, s);
    }

    function transfer(address to, uint256 value)
        public
        virtual
        override(IERC20, ARTHERC20Custom)
        requireValidRecipient(to)
        returns (bool)
    {
        return super.transfer(to, value);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        public
        virtual
        override(IERC20, ARTHERC20Custom)
        requireValidRecipient(recipient)
        onlyNonBlacklisted(_msgSender())
        returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }

    function revokeRebase() public onlyByOwnerOrGovernance {
        allowRebase = false;
    }

    function totalSupply() public view override(ARTHERC20Custom, IERC20) returns (uint256) {
        return _totalSupply.div(gonsPerFragment);
    }

    function rebase(uint256 _newGonsPerFragment) external onlyByOwnerOrGovernance returns (uint256) {
        require(allowRebase, "Arth: rebase is revoked");
        gonsPerFragment = _newGonsPerFragment;

        emit Rebase(totalSupply());
        return totalSupply();
    }

    function balanceOf(address account)
        public
        view
        override(IERC20, ARTHERC20Custom)
        returns (uint256)
    {
        return _balances[account].div(gonsPerFragment);
    }

    function _mint(address account, uint256 amount) internal override onlyNonBlacklisted(account) {
        require(account != address(0), "ERC20: mint to the zero address");

        uint256 gonValues = amount.mul(gonsPerFragment);

        _totalSupply = _totalSupply.add(gonValues);
        _balances[account] = _balances[account].add(gonValues);

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal override onlyNonBlacklisted(account) {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 gonValues = amount.mul(gonsPerFragment);

        _balances[account] = _balances[account].sub(gonValues, "ERC20: burn amount exceeds balance");

        _totalSupply = _totalSupply.sub(gonValues);

        emit Transfer(account, address(0), amount);
    }

    /// @notice Used by pools when user redeems.
    function poolBurnFrom(address who, uint256 amount) external override onlyPools {
        super._burnFrom(who, amount);
        emit PoolBurned(who, msg.sender, amount);
    }

    /// @notice This function is what other arth pools will call to mint new ARTH
    function poolMint(address who, uint256 amount) external override onlyPools {
        _mint(who, amount);
        emit PoolMinted(msg.sender, who, amount);
    }

    function setArthController(address _controller) external override onlyOwner {
        controller = IARTHController(_controller);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 value
    ) internal override {
        // get amount in underlying
        uint256 gonValues = value.mul(gonsPerFragment);

        // sub from balance of sender
        _balances[sender] = _balances[sender].sub(gonValues);

        // add to balance of receiver
        _balances[recipient] = _balances[recipient].add(gonValues);
        emit Transfer(msg.sender, recipient, value);
    }
}
