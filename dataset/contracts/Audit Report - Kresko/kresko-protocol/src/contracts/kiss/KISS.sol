// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

// solhint-disable-next-line
import {AccessControlEnumerableUpgradeable, AccessControlUpgradeable, IAccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {ERC20Upgradeable} from "../shared/ERC20Upgradeable.sol";
import {IKreskoAssetIssuer} from "../kreskoasset/IKreskoAssetIssuer.sol";
import {IKISS, IERC165} from "./interfaces/IKISS.sol";
import {Role} from "../libs/Authorization.sol";
import {Error} from "../libs/Errors.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/* solhint-disable not-rely-on-time */

/**
 * @title Kresko Integrated Stable System
 * This is a non-rebasing Kresko Asset, intended to be paired to a stable-value underlying.
 * @author Kresko
 */
contract KISS is IKISS, ERC20Upgradeable, PausableUpgradeable, AccessControlEnumerableUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant OPERATOR_ROLE = 0x112e48a576fb3a75acc75d9fcf6e0bc670b27b1dbcd2463502e10e68cf57d6fd;

    modifier onlyContract() {
        require(msg.sender.code.length > 0, Error.CALLER_NOT_CONTRACT);
        _;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Layout                                   */
    /* -------------------------------------------------------------------------- */

    uint256 public pendingOperatorWaitPeriod;
    uint256 public pendingOperatorUnlockTime;
    uint256 public maxOperators;
    address public pendingOperator;
    address public kresko;

    /* -------------------------------------------------------------------------- */
    /*                                   Writes                                   */
    /* -------------------------------------------------------------------------- */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 dec_,
        address admin_,
        address kresko_
    ) external initializer {
        // Few sanity checks, we do not want EOA's here
        require(kresko_.code.length > 0, Error.KRESKO_NOT_CONTRACT);
        // require(admin_.code.length > 0, Error.ADMIN_NOT_A_CONTRACT);

        // ERC20
        name = name_;
        symbol = symbol_;
        decimals = dec_;
        kresko = kresko_;

        // 2 operators needed at the time of writing, the volative market and the stable market.
        maxOperators = 2;

        // 15 minutes to wait before the operator can accept the role, this is the minimum value that can be set.
        pendingOperatorWaitPeriod = 15 minutes;

        // Setup the admin
        _setupRole(Role.DEFAULT_ADMIN, admin_);
        _setupRole(Role.ADMIN, admin_);

        // Setup the protocol
        kresko = kresko_;
        _setupRole(Role.OPERATOR, kresko_);
        _setupRole(MINTER_ROLE, kresko_);
        _setupRole(PAUSER_ROLE, kresko_);

        // Deployer does not need roles, uncomment for mainnet
        renounceRole(MINTER_ROLE, msg.sender);
        renounceRole(PAUSER_ROLE, msg.sender);
        // renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public pure override(AccessControlEnumerableUpgradeable, IERC165) returns (bool) {
        return
            interfaceId != 0xffffffff &&
            (interfaceId == type(IKISS).interfaceId ||
                interfaceId == type(IKreskoAssetIssuer).interfaceId ||
                interfaceId == 0x01ffc9a7 ||
                interfaceId == 0x36372b07);
    }

    /// @inheritdoc IKISS
    function issue(
        uint256 _amount,
        address _to
    ) public override onlyContract onlyRole(Role.OPERATOR) returns (uint256) {
        _mint(_to, _amount);
        return _amount;
    }

    /// @inheritdoc IKISS
    function mint(address _to, uint256 _amount) public onlyContract onlyRole(Role.OPERATOR) {
        _mint(_to, _amount);
    }

    /// @inheritdoc IKISS
    function destroy(uint256 _amount, address _from) external onlyContract onlyRole(Role.OPERATOR) returns (uint256) {
        _burn(_from, _amount);
        return _amount;
    }

    /// @inheritdoc IKISS
    function pause() public onlyContract onlyRole(Role.ADMIN) {
        super._pause();
    }

    /// @inheritdoc IKISS
    function unpause() public onlyContract onlyRole(Role.ADMIN) {
        _unpause();
    }

    /// @inheritdoc IKISS
    function setPendingOperatorWaitPeriod(uint256 _newPeriod) external onlyRole(Role.ADMIN) {
        require(_newPeriod >= 15 minutes, Error.OPERATOR_WAIT_PERIOD_TOO_SHORT);
        pendingOperatorWaitPeriod = _newPeriod;
        emit NewPendingOperatorWaitPeriod(_newPeriod);
    }

    /// @inheritdoc IKISS
    function setMaxOperators(uint256 _maxOperators) external onlyRole(Role.ADMIN) {
        maxOperators = _maxOperators;
        emit NewMaxOperators(_maxOperators);
    }

    /// @inheritdoc IKISS
    function grantRole(
        bytes32 _role,
        address _to
    ) public override(IKISS, AccessControlUpgradeable, IAccessControlUpgradeable) onlyRole(Role.ADMIN) {
        // Default behavior
        if (_role != Role.OPERATOR) {
            _grantRole(_role, _to);
            return;
        }

        // Handle the operator role
        require(_to.code.length > 0, Error.OPERATOR_NOT_CONTRACT);
        if (pendingOperator != address(0)) {
            // Ensure cooldown period
            require(pendingOperatorUnlockTime < block.timestamp, Error.OPERATOR_WAIT_PERIOD_NOT_OVER);
            // Grant role
            _grantRole(Role.OPERATOR, pendingOperator);
            emit NewOperator(_msgSender());
            // Reset pending owner
            // No need to touch the timestamp (next call will just trigger the cooldown period)
            pendingOperator = address(0);
        } else if (pendingOperatorUnlockTime != 0) {
            // Do not allow more than `maxOperators` of operators
            require(getRoleMemberCount(Role.OPERATOR) < maxOperators, Error.OPERATOR_LIMIT_REACHED);
            // Set the timestamp for the cooldown period
            pendingOperatorUnlockTime = block.timestamp + pendingOperatorWaitPeriod;
            // Set the pending oeprator, execution to upper if clause next call as this pending operator is set
            pendingOperator = _to;
            emit NewOperatorInitialized(_to, pendingOperatorUnlockTime);
        } else {
            // Initialize operator for the first time
            _grantRole(Role.OPERATOR, _to);
            emit NewOperator(_to);
            // Set the timestamp, execution will not come here again
            pendingOperatorUnlockTime = block.timestamp;
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Views                                   */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IKreskoAssetIssuer
    function convertToShares(uint256 assets) external pure returns (uint256) {
        return assets;
    }

    /// @inheritdoc IKreskoAssetIssuer
    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  internal                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "KISS: Paused");
    }
}
