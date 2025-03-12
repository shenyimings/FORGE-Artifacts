// SPDX-License-Identifier: AGPL-3.0-or-later
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../interfaces/IStablecoin.sol";

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

contract AlpacaStablecoin is IStablecoin, AccessControlUpgradeable {
  bytes32 public constant OWNER_ROLE = DEFAULT_ADMIN_ROLE;
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  // --- ERC20 Data ---
  string public name; // Alpaca USD Stablecoin
  string public symbol; // AUSD
  string public constant version = "1";
  uint256 public constant override decimals = 18;
  uint256 public totalSupply;

  mapping(address => uint256) public override balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;
  mapping(address => uint256) public nonces;

  event Approval(address indexed src, address indexed guy, uint256 wad);
  event Transfer(address indexed src, address indexed dst, uint256 wad);

  // --- Math ---
  function add(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require((_z = _x + _y) >= _x);
  }

  function sub(uint256 _x, uint256 _y) internal pure returns (uint256 _z) {
    require((_z = _x - _y) <= _x);
  }

  // --- EIP712 niceties ---
  bytes32 public DOMAIN_SEPARATOR;
  // bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
  bytes32 public constant PERMIT_TYPEHASH = 0xea2aa0a1be11a07ed86d755c93467f4f82362b452371d1ba94d1715123511acb;

  // --- Init ---
  function initialize(
    string memory _name,
    string memory _symbol,
    uint256 _chainId
  ) external initializer {
    AccessControlUpgradeable.__AccessControl_init();

    name = _name;
    symbol = _symbol;

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes(name)),
        keccak256(bytes(version)),
        _chainId,
        address(this)
      )
    );

    // Grant the contract deployer the default admin role: it will be able
    // to grant and revoke any roles
    _setupRole(OWNER_ROLE, msg.sender);
  }

  // --- Token ---
  function transfer(address _dst, uint256 _wad) external override returns (bool) {
    return transferFrom(msg.sender, _dst, _wad);
  }

  function transferFrom(
    address _src,
    address _dst,
    uint256 _wad
  ) public override returns (bool) {
    require(balanceOf[_src] >= _wad, "AlpacaStablecoin/insufficient-balance");
    if (_src != msg.sender && allowance[_src][msg.sender] != uint256(-1)) {
      require(allowance[_src][msg.sender] >= _wad, "AlpacaStablecoin/insufficient-allowance");
      allowance[_src][msg.sender] = sub(allowance[_src][msg.sender], _wad);
    }
    balanceOf[_src] = sub(balanceOf[_src], _wad);
    balanceOf[_dst] = add(balanceOf[_dst], _wad);
    emit Transfer(_src, _dst, _wad);
    return true;
  }

  function mint(address _usr, uint256 _wad) external override {
    require(hasRole(MINTER_ROLE, msg.sender), "!minterRole");

    balanceOf[_usr] = add(balanceOf[_usr], _wad);
    totalSupply = add(totalSupply, _wad);
    emit Transfer(address(0), _usr, _wad);
  }

  function burn(address _usr, uint256 _wad) external override {
    require(balanceOf[_usr] >= _wad, "AlpacaStablecoin/insufficient-balance");
    if (_usr != msg.sender && allowance[_usr][msg.sender] != uint256(-1)) {
      require(allowance[_usr][msg.sender] >= _wad, "AlpacaStablecoin/insufficient-allowance");
      allowance[_usr][msg.sender] = sub(allowance[_usr][msg.sender], _wad);
    }
    balanceOf[_usr] = sub(balanceOf[_usr], _wad);
    totalSupply = sub(totalSupply, _wad);
    emit Transfer(_usr, address(0), _wad);
  }

  function approve(address _usr, uint256 _wad) external override returns (bool) {
    allowance[msg.sender][_usr] = _wad;
    emit Approval(msg.sender, _usr, _wad);
    return true;
  }

  // --- Alias ---
  function push(address _usr, uint256 _wad) external {
    transferFrom(msg.sender, _usr, _wad);
  }

  function pull(address _usr, uint256 _wad) external {
    transferFrom(_usr, msg.sender, _wad);
  }

  function move(
    address _src,
    address _dst,
    uint256 _wad
  ) external {
    transferFrom(_src, _dst, _wad);
  }

  // --- Approve by signature ---
  function permit(
    address _holder,
    address _spender,
    uint256 _nonce,
    uint256 _expiry,
    bool _allowed,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external {
    bytes32 _digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(PERMIT_TYPEHASH, _holder, _spender, _nonce, _expiry, _allowed))
      )
    );

    require(_holder != address(0), "AlpacaStablecoin/invalid-address-0");
    require(_holder == ecrecover(_digest, _v, _r, _s), "AlpacaStablecoin/invalid-permit");
    require(_expiry == 0 || now <= _expiry, "AlpacaStablecoin/permit-expired");
    require(_nonce == nonces[_holder]++, "AlpacaStablecoin/invalid-nonce");
    uint256 _wad = _allowed ? uint256(-1) : 0;
    allowance[_holder][_spender] = _wad;
    emit Approval(_holder, _spender, _wad);
  }
}
