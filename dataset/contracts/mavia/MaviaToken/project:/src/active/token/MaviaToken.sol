// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MaviaToken is ERC20, AccessControl {
  using SafeERC20 for IERC20;
  uint256 private constant _MAX_UINT = type(uint256).max;
  bytes32 private constant _EDITOR_ROLE = keccak256("_EDITOR_ROLE");
  bytes32 private constant _EMERGENCY_ROLE = keccak256("_EMERGENCY_ROLE");

  bytes32 private _DOMAIN_SEPARATOR;
  // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
  bytes32 private constant _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
  mapping(address => uint) public nonces;

  mapping(address => bool) public blacklist;
  mapping(address => bool) public whitelist;
  uint256 public tfStartTime;
  uint256 public tfMaxAmount;

  event ESetBlacklist(address indexed _pAddr, bool _pIsBlacklist);
  event ESetWhitelist(address indexed _pAddr, bool _pIsWhitelist);
  event ESetGateway(address indexed _pAddr, bool _pIsGateway);
  event ESetTradeTime(uint256 _pStartTime, uint256 _pMaxAmount);
  event EEmerERC20Tokens(IERC20 indexed _pToken, address _pTo);

  constructor() ERC20("Heroes of Mavia", "MAVIA") {
    _DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes("TokenPermit")),
        keccak256(bytes("1")),
        block.chainid,
        address(this)
      )
    );

    address sender_ = _msgSender();
    _setupRole(DEFAULT_ADMIN_ROLE, sender_);
    _setupRole(_EDITOR_ROLE, sender_);

    tfMaxAmount = _MAX_UINT;
    _mint(sender_, 250_000_000 * 1e18);
  }

  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
    require(deadline >= block.timestamp, "Sig: EXPIRED");
    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        _DOMAIN_SEPARATOR,
        keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
      )
    );
    address recoveredAddress = ecrecover(digest, v, r, s);
    require(recoveredAddress != address(0) && recoveredAddress == owner, "Sig: INVALID_SIGNATURE");
    _approve(owner, spender, value);
  }

  /**
   * @dev Allow burn
   */
  function fBurn(uint256 _pAmount) external {
    _burn(_msgSender(), _pAmount);
  }

  function fSetBlacklist(address _pAddr, bool _pIsBlacklist) external onlyRole(_EDITOR_ROLE) {
    require(_pAddr != address(0), "Invalid address");
    blacklist[_pAddr] = _pIsBlacklist;
    emit ESetBlacklist(_pAddr, _pIsBlacklist);
  }

  function fSetWhitelist(address _pAddr, bool _pIsWhitelist) external onlyRole(_EDITOR_ROLE) {
    require(_pAddr != address(0), "Invalid address");
    whitelist[_pAddr] = _pIsWhitelist;
    emit ESetWhitelist(_pAddr, _pIsWhitelist);
  }

  function fSetTradeTime(uint256 _pStartTime, uint256 _pMaxAmount) external onlyRole(_EDITOR_ROLE) {
    tfStartTime = _pStartTime;
    tfMaxAmount = _pMaxAmount;
    emit ESetTradeTime(_pStartTime, _pMaxAmount);
  }

  function fEmerERC20Tokens(IERC20 _pToken, address _pTo) external onlyRole(_EMERGENCY_ROLE) {
    require(_pTo != address(0), "Invalid address");
    uint256 bal_ = _pToken.balanceOf(address(this));
    _pToken.safeTransfer(_pTo, bal_);
    emit EEmerERC20Tokens(_pToken, _pTo);
  }

  /**
   * @dev Override ERC20 transfer the tokens
   */
  function _transfer(address _pSender, address _pRecipient, uint256 _pAmount) internal override {
    require(!blacklist[_pSender] && !blacklist[_pRecipient], "Blacklist");
    if (!whitelist[_pSender] && !whitelist[_pRecipient]) {
      require(block.timestamp >= tfStartTime, "Invalid time");
      require(_pAmount <= tfMaxAmount, "Invalid amount");
    }
    super._transfer(_pSender, _pRecipient, _pAmount);
  }
}
