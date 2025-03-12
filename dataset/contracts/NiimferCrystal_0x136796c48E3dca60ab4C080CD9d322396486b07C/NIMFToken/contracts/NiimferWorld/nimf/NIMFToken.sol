// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./INimfToken.sol";

contract NIMFToken is ERC20, AccessControlEnumerable, INimfToken {
    /* ========== DECLARE =============== */
    using SafeMath for uint256;

    uint256 public cap;

    mapping(address => bool) public minter;

    address public officialAccount;
    uint256 private _totalBurned;

    bytes32 public constant NIMF_GOVERNANCE = keccak256("NIMF_GOVERNANCE");
    bytes32 public constant NIMF_MINTER = keccak256("NIMF_MINTER");

    /* ========== EVENTS ========== */

    event OnUpdateMinter(address indexed account, bool isMinter);

    event OnUpdateOfficialAccount(address account);

    /* ========== GOVERNANCE ========== */

    constructor() ERC20("NIMF", "NIMF") {
        cap = 100000000 ether; // Max Supply: 1 billion NIMF
        _mint(_msgSender(), (cap * 15) / 100); // Private sale + IDO + Airdrop + Advisor: 15%
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(NIMF_GOVERNANCE, msg.sender);
        _setupRole(NIMF_MINTER, msg.sender);
        officialAccount = msg.sender;
    }

    function setCap(uint256 _newCap) external onlyRole(NIMF_GOVERNANCE) {
        require(totalSupply() <= _newCap, "exceeds current supply");
        cap = _newCap;
    }

    function setMinter(address _account, bool _minter) external onlyRole(NIMF_GOVERNANCE) {
        require(_account != address(0), "zero");
        minter[_account] = _minter;
        emit OnUpdateMinter(_account, _minter);
    }

    function setOfficialAccount(address _account) external onlyRole(NIMF_GOVERNANCE) {
        require(_account != address(0), "zero");
        officialAccount = _account;
        emit OnUpdateOfficialAccount(_account);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function totalBurned() external view returns (uint256) {
        return _totalBurned;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function mint(address _recipient, uint256 _amount) external override onlyRole(NIMF_MINTER) returns (bool) {
        uint256 balanceBefore = balanceOf(_recipient);
        _mint(_recipient, _amount);
        return balanceOf(_recipient) > balanceBefore;
    }

    /**
     * Emit transfer() event
     */
    function burn(uint256 _amount) external override {
        _burn(msg.sender, _amount);
    }

    function burnFrom(address _account, uint256 _amount) external override {
        _approve(
            _account,
            _msgSender(),
            allowance(_account, _msgSender()).sub(_amount, "ERC20: burn amount exceeds allowance")
        );
        _burn(_account, _amount);
    }

    /* ========== OVERRIDE STANDARD FUNCTIONS ========== */

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `_account` cannot be the zero address.
     * - `_account` must have at least `_amount` tokens.
     */
    function _burn(address _account, uint256 _amount) internal override {
        super._burn(_account, _amount);
        _totalBurned = _totalBurned.add(_amount);
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - minted tokens must not cause the total supply to go over the cap.
     */
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        super._beforeTokenTransfer(_from, _to, _amount);
        if (_from == address(0)) {
            // When minting tokens
            require(totalSupply().add(_amount) <= cap, "cap exceeded");
        }
        if (_to == address(0)) {
            // When burning tokens
            cap = cap.sub(_amount, "burn amount exceeds cap");
        }
    }

    /* ========== EMERGENCY ========== */

    function withdrawERC20Token(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).transfer(officialAccount, IERC20(_token).balanceOf(address(this)));
    }
}
