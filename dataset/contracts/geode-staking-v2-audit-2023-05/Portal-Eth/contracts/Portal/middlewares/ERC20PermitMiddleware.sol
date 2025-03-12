// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/extensions/draft-ERC20Permit.sol)

pragma solidity =0.8.7;

// interfaces
import {IERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";
// libraries
import {BytesLib} from "../helpers/BytesLib.sol";
// contracts
import {ERC20Middleware} from "./ERC20Middleware.sol";
// external
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {CountersUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/**
 * @dev differences between ERC20PermitMiddleware and Openzeppelin's implementation of ERC20PermitUpgradable is:
 * -> pragma set to =0.8.7;
 * -> using ERC20Middleware instead of ERC20Upgradeable
 * -> added initialize
 *
 * https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/54803be62207c2412e27d09325243f2f1452f7b9/contracts/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol
 */

/**
 * @dev Implementation of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on `{IERC20-approve}`, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * _Available since v3.4._
 *
 * @custom:storage-size 51
 */
contract ERC20PermitMiddleware is ERC20Middleware, IERC20PermitUpgradeable, EIP712Upgradeable {
  using CountersUpgradeable for CountersUpgradeable.Counter;

  mapping(address => CountersUpgradeable.Counter) private _nonces;

  // solhint-disable-next-line var-name-mixedcase
  bytes32 private constant _PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

  /**
   * @dev In previous versions `_PERMIT_TYPEHASH` was declared as `immutable`.
   * However, to ensure consistency with the upgradeable transpiler, we will continue
   * to reserve a slot.
   * @custom:oz-renamed-from _PERMIT_TYPEHASH
   *
   * @dev GEODE: we don't need this.
   */
  // solhint-disable-next-line var-name-mixedcase
  // bytes32 private _PERMIT_TYPEHASH_DEPRECATED_SLOT;

  ///@custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Sets the values for {name} and {symbol}.
   *
   * The default value of {decimals} is 18. To select a different value for
   * {decimals} you should overload it.
   *
   */
  function initialize(
    uint256 id_,
    address gETH_,
    bytes calldata data
  ) public virtual override initializer {
    uint256 nameLen = uint256(bytes32(BytesLib.slice(data, 0, 32)));
    __ERC20MiddlewarePermit_init(
      id_,
      gETH_,
      string(BytesLib.slice(data, 32, nameLen)),
      string(BytesLib.slice(data, 32 + nameLen, data.length - (32 + nameLen)))
    );
  }

  /**
   * @dev Initializes the {EIP712} domain separator using the `name` parameter, and setting `version` to `"1"`.
   *
   * It's a good idea to use the same `name` that is defined as the ERC20 token name.
   */
  function __ERC20MiddlewarePermit_init(
    uint256 id_,
    address gETH_,
    string memory name_,
    string memory symbol_
  ) internal onlyInitializing {
    __EIP712_init(name_, "1");
    __ERC20Middleware_init(id_, gETH_, name_, symbol_);
    __ERC20MiddlewarePermit_init_unchained();
  }

  function __ERC20MiddlewarePermit_init_unchained() internal onlyInitializing {}

  /**
   * @dev See {IERC20Permit-permit}.
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public virtual override {
    require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

    bytes32 structHash = keccak256(
      abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline)
    );

    bytes32 hash = _hashTypedDataV4(structHash);

    address signer = ECDSAUpgradeable.recover(hash, v, r, s);
    require(signer == owner, "ERC20Permit: invalid signature");

    _approve(owner, spender, value);
  }

  /**
   * @dev See {IERC20Permit-nonces}.
   */
  function nonces(address owner) public view virtual override returns (uint256) {
    return _nonces[owner].current();
  }

  /**
   * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
   */
  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view override returns (bytes32) {
    return _domainSeparatorV4();
  }

  /**
   * @dev "Consume a nonce": return the current value and increment.
   *
   * _Available since v4.1._
   */
  function _useNonce(address owner) internal virtual returns (uint256 current) {
    CountersUpgradeable.Counter storage nonce = _nonces[owner];
    current = nonce.current();
    nonce.increment();
  }

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   *
   * @dev GEODE: middlewares are de-facto not upgrdable, just here to be cloned.
   * * So, we don't need this gap.
   */
  // uint256[] private __gap;
}
