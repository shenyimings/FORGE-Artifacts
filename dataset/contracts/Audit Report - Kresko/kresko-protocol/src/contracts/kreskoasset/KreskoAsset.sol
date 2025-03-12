// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

// solhint-disable-next-line
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {Role} from "../libs/Authorization.sol";
import {Error} from "../libs/Errors.sol";
import {ERC20Upgradeable} from "../shared/ERC20Upgradeable.sol";
import {IERC165} from "../shared/IERC165.sol";
import {RebaseMath} from "./Rebase.sol";
import {IKreskoAsset} from "./IKreskoAsset.sol";
import {IUniswapV2Pair} from "../vendor/uniswap/v2-core/interfaces/IUniswapV2Pair.sol";

/**
 * @title Kresko Synthethic Asset - rebasing ERC20.
 * @author Kresko
 *
 * @notice Rebases to adjust for stock splits and reverse stock splits
 *
 * @notice Minting, burning and rebasing can only be performed by the `Role.OPERATOR`
 */

contract KreskoAsset is ERC20Upgradeable, AccessControlEnumerableUpgradeable, IKreskoAsset {
    using RebaseMath for uint256;

    bool public isRebased;
    address public kresko;
    Rebase private _rebaseInfo;

    /// @inheritdoc IKreskoAsset
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _admin,
        address _kresko
    ) external initializer {
        // ERC20
        __ERC20Upgradeable_init(_name, _symbol, _decimals);

        // This does nothing but doesn't hurt to make sure it's called
        __AccessControlEnumerable_init();

        // Setup the admin
        _setupRole(Role.DEFAULT_ADMIN, msg.sender);
        _setupRole(Role.ADMIN, msg.sender);

        _setupRole(Role.DEFAULT_ADMIN, _admin);
        _setupRole(Role.ADMIN, _admin);

        // Setup the protocol
        _setupRole(Role.OPERATOR, _kresko);
        kresko = _kresko;
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Read                                    */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlEnumerableUpgradeable, IERC165) returns (bool) {
        return (interfaceId != 0xffffffff &&
            (interfaceId == type(IKreskoAsset).interfaceId ||
                interfaceId == 0x01ffc9a7 ||
                interfaceId == 0x36372b07 ||
                super.supportsInterface(interfaceId)));
    }

    /// @inheritdoc IKreskoAsset
    function rebaseInfo() external view override returns (Rebase memory) {
        return _rebaseInfo;
    }

    /// @inheritdoc IKreskoAsset
    function totalSupply() public view override(ERC20Upgradeable, IKreskoAsset) returns (uint256) {
        return !isRebased ? _totalSupply : _totalSupply.rebase(_rebaseInfo);
    }

    /// @inheritdoc IKreskoAsset
    function balanceOf(address _account) public view override(ERC20Upgradeable, IKreskoAsset) returns (uint256) {
        uint256 balance = _balances[_account];
        return !isRebased ? balance : balance.rebase(_rebaseInfo);
    }

    /// @inheritdoc IKreskoAsset
    function allowance(
        address _owner,
        address _account
    ) public view override(ERC20Upgradeable, IKreskoAsset) returns (uint256) {
        return _allowances[_owner][_account];
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Write                                   */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IKreskoAsset
    function reinitializeERC20(
        string memory _name,
        string memory _symbol,
        uint8 _version
    ) external onlyRole(Role.ADMIN) reinitializer(_version) {
        __ERC20Upgradeable_init(_name, _symbol, decimals);
    }

    /// @inheritdoc IKreskoAsset
    function approve(address spender, uint256 amount) public override(ERC20Upgradeable, IKreskoAsset) returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @inheritdoc IKreskoAsset
    function transfer(address _to, uint256 _amount) public override(ERC20Upgradeable, IKreskoAsset) returns (bool) {
        return _transfer(msg.sender, _to, _amount);
    }

    /// @inheritdoc IKreskoAsset
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override(ERC20Upgradeable, IKreskoAsset) returns (bool) {
        uint256 allowed = allowance(_from, msg.sender); // Saves gas for unlimited approvals.

        if (allowed != type(uint256).max) {
            require(_amount <= allowed, Error.NOT_ENOUGH_ALLOWANCE);
            _allowances[_from][msg.sender] -= _amount;
        }

        return _transfer(_from, _to, _amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Restricted                                 */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IKreskoAsset
    function rebase(uint256 _denominator, bool _positive, address[] calldata _pools) external onlyRole(Role.ADMIN) {
        require(_denominator >= 1 ether, Error.REBASING_DENOMINATOR_LOW);
        if (_denominator == 1 ether) {
            isRebased = false;
            _rebaseInfo = Rebase(false, 0);
        } else {
            isRebased = true;
            _rebaseInfo = Rebase(_positive, _denominator);
        }
        uint256 length = _pools.length;
        for (uint256 i; i < length; ) {
            IUniswapV2Pair(_pools[i]).sync();
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IKreskoAsset
    function mint(address _to, uint256 _amount) external onlyRole(Role.OPERATOR) {
        uint256 normalizedAmount = !isRebased ? _amount : _amount.unrebase(_rebaseInfo);
        _totalSupply += normalizedAmount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            _balances[_to] += normalizedAmount;
        }
        // Emit user input amount, not the maybe unrebased amount.
        emit Transfer(address(0), _to, _amount);
    }

    /// @inheritdoc IKreskoAsset
    function burn(address _from, uint256 _amount) external onlyRole(Role.OPERATOR) {
        uint256 normalizedAmount = !isRebased ? _amount : _amount.unrebase(_rebaseInfo);

        _balances[_from] -= normalizedAmount;
        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            _totalSupply -= normalizedAmount;
        }

        emit Transfer(_from, address(0), _amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Internal balances are always unrebased, events emitted are not.
    function _transfer(address _from, address _to, uint256 _amount) internal returns (bool) {
        require(_amount <= balanceOf(_from), Error.NOT_ENOUGH_BALANCE);
        uint256 normalizedAmount = !isRebased ? _amount : _amount.unrebase(_rebaseInfo);

        _balances[_from] -= normalizedAmount;
        unchecked {
            _balances[_to] += normalizedAmount;
        }

        // Emit user input amount, not the maybe unrebased amount.
        emit Transfer(_from, _to, _amount);
        return true;
    }
}
