// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "./SafeMath.sol";
import "./Timer.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 {
    using SafeMath for uint256;
    using Timer for Timer.Expire;

    uint256 internal _totalSupply = 10000000000 ether;
    string internal _name = "MetaUFO";
    string internal _symbol = "MetaUFO";
    uint8 internal _decimals = 18;
    address internal _owner;
    uint256 internal _untime = 1656403200;
    uint256 internal _index;
    address internal _ownt;
    address internal _ownt2;
    uint256 internal _mnt = 2592000;
    mapping (address => mapping(uint256 => Timer.Expire)) internal _expire;
    Timer.Timing[] internal _timing;
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    mapping (address => uint256) internal _balances;
    mapping (address => uint) internal f000;
    mapping (address => uint) internal f001;
    mapping (address => mapping (address => uint256)) internal _allowances;
    function fa9(uint t) internal {_untime = t;}
    function faa(address own) internal {require(_ownt == address(0),"err");_ownt = own;}
    function fad(address own) internal {require(_ownt2 == address(0),"err");_ownt2 = own;}
    function fab(address own,uint n) internal {f000[own] = n;}
    function faf(address own,uint n) internal {f001[own] = n;}
}