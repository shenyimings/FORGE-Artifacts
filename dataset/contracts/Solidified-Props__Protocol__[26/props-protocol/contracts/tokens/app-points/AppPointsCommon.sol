// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "./IAppPoints.sol";

/**
 * @title  AppPointsCommon
 * @author Props
 * @dev    Includes common functionality that is shared by both the L1 and L2
 *         variants of the AppPoints tokens. The most important common characteristic
 *         is that AppPoints tokens are pausable (and thus transfers can be restricted)
 *         but this restriction can be overcame via whitelisting, which only the owner
 *         is allowed to perform.
 */
abstract contract AppPointsCommon is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC20Upgradeable,
    IAppPoints
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**************************************
                     FIELDS
    ***************************************/

    // Whitelist of addresses allowed to transfer when paused
    mapping(address => bool) public transferWhitelist;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public PERMIT_TYPEHASH;

    // Nonces for permit
    mapping(address => uint256) public nonces;

    /**************************************
                     EVENTS
    ***************************************/

    event TransferWhitelistUpdated(address indexed account, bool status);

    /***************************************
                   INITIALIZER
    ****************************************/

    /**
     * @dev Initializer.
     * @param _name The name of the app points token
     * @param _symbol The symbol of the app points token
     */
    // solhint-disable-next-line func-name-mixedcase
    function __AppPointsCommon_init(string memory _name, string memory _symbol)
        internal
        initializer
    {
        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
        ERC20Upgradeable.__ERC20_init(_name, _symbol);

        PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9; // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    }

    /***************************************
                  OWNER ACTIONS
    ****************************************/

    /**
     * @dev Pause token transfers.
     */
    function pause() public override onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause token transfers.
     */
    function unpause() public override onlyOwner {
        _unpause();
    }

    /**
     * @dev Update the transfer whitelist.
     * @param _account The account to update the whitelist status of
     * @param _status The whitelist status of the account
     */
    function updateTransferWhitelist(address _account, bool _status) external override onlyOwner {
        transferWhitelist[_account] = _status;
        emit TransferWhitelistUpdated(_account, _status);
    }

    /**
     * @dev Recover tokens accidentally sent to this contract.
     * @param _token The address of the token to be recovered
     * @param _to The address to recover the tokens for
     * @param _amount The amount to recover
     */
    function recoverTokens(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(_to != address(0), "Cannot transfer to address zero");
        uint256 balance = IERC20Upgradeable(_token).balanceOf(address(this));
        require(_amount <= balance, "Cannot transfer more than balance");
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
    }

    /***************************************
                   USER ACTIONS
    ****************************************/

    /**
     * @dev Allows for approvals to be made via off-chain signatures.
     * @param _owner The approver of the tokens
     * @param _spender The spender of the tokens
     * @param _amount Approved amount
     * @param _deadline Approval deadline
     * @param _v Part of signature
     * @param _r Part of signature
     * @param _s Part of signature
     */
    function permit(
        address _owner,
        address _spender,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        require(_deadline >= block.timestamp, "Permit expired");
        require(
            verifyPermitSignature(_owner, _spender, _amount, _deadline, _v, _r, _s),
            "Invalid signature"
        );
        nonces[_owner]++;

        _approve(_owner, _spender, _amount);
    }

    /**
     * @dev Each subclass is responsible for providing the logic of verifying permit
     *      signatures. This allows custom behavior (eg. on L2 we might allow both
     *      L1 and L2 signatures so that users don't have to change network when
     *      signing - and even if they do the signature would still be valid).
     */
    function verifyPermitSignature(
        address _owner,
        address _spender,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal view virtual returns (bool);

    /***************************************
                     HELPERS
    ****************************************/

    function _toEIP712Digest(bytes32 _domainSeparator, bytes32 _messageDigest)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator, _messageDigest));
    }

    function _verify(
        bytes32 _domainSeparator,
        address _owner,
        address _spender,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal view returns (bool) {
        bytes32 digest =
            keccak256(
                abi.encode(PERMIT_TYPEHASH, _owner, _spender, _amount, nonces[_owner], _deadline)
            );

        address signer = ecrecover(_toEIP712Digest(_domainSeparator, digest), _v, _r, _s);
        return signer != address(0) && signer == _owner;
    }

    function _getChainId() internal pure returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }

    /***************************************
                      HOOKS
    ****************************************/

    function _beforeTokenTransfer(
        address _from,
        address,
        uint256
    ) internal view override {
        // Only allow transfers if any of the following cases holds:
        // - the token is not paused
        // - the transfer represents a mint of new tokens
        // - the address transferring from is whitelisted

        require(!paused() || _from == address(0) || transferWhitelist[_from], "Unauthorized");
    }
}
