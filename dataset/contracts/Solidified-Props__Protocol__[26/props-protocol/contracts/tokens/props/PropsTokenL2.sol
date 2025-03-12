// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./IPropsTokenL2.sol";

/**
 * @title  PropsTokenL2
 * @author Props
 * @dev    The L2 version of the Props token. Props tokens residing on L1
 *         can be moved on the L2 where the Props protocol resides and be
 *         used there for interacting with the protocol.
 */
contract PropsTokenL2 is Initializable, OwnableUpgradeable, ERC20Upgradeable, IPropsTokenL2 {
    using SafeMathUpgradeable for uint256;

    /**************************************
                     FIELDS
    ***************************************/

    // Set of addresses permissioned to mint additional L2 Props
    mapping(address => bool) public isMinter;

    // solhint-disable-next-line var-name-mixedcase
    uint256 public ROOT_CHAIN_ID;
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DOMAIN_SEPARATOR_L1;
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DOMAIN_SEPARATOR_L2;
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public PERMIT_TYPEHASH;
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public PERMIT_AND_CALL_TYPEHASH;

    // Nonces for permit
    mapping(address => uint256) public nonces;

    /***************************************
                   INITIALIZER
    ****************************************/

    /**
     * @dev Initializer.
     * @param _owner The owner of the contract
     */
    function initialize(address _owner) public initializer {
        OwnableUpgradeable.__Ownable_init();
        ERC20Upgradeable.__ERC20_init("Props", "PROPS");

        transferOwnership(_owner);

        // The root chain id must correspond to the chain id of the underlying root Ethereum network (either mainnet or testnet)
        // This way, users won't have to change networks in order to be able to sign transactions
        ROOT_CHAIN_ID = 1;

        DOMAIN_SEPARATOR_L1 = keccak256(
            abi.encode(
                // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes(name())),
                keccak256(bytes("1")),
                ROOT_CHAIN_ID,
                address(this)
            )
        );

        DOMAIN_SEPARATOR_L2 = keccak256(
            abi.encode(
                // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes(name())),
                keccak256(bytes("1")),
                _getChainId(),
                address(this)
            )
        );

        // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
        PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
        // keccak256("PermitAndCall(address owner,address spender,uint256 value,address callTo,bytes callData,uint256 nonce,uint256 deadline)")
        PERMIT_AND_CALL_TYPEHASH = 0x372f0368a822e115c12612c14ba8201411bafdc6b0c2a9593736434cd00c7f3a;
    }

    /***************************************
                  ADMIN ACTIONS
    ****************************************/

    /**
     * @dev Give minting permissions to an address.
     * @param _minter The address to give minting permissions to
     */
    function addMinter(address _minter) external onlyOwner {
        isMinter[_minter] = true;
    }

    /**
     * @dev Remove minting permissions from an address.
     * @param _minter The address to remove minting permissions from
     */
    function removeMinter(address _minter) external onlyOwner {
        isMinter[_minter] = false;
    }

    /***************************************
                 MINTER ACTIONS
    ****************************************/

    /**
     * @dev Mint new tokens to an account.
     * @param _account The address to mint to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _account, uint256 _amount) external override {
        require(isMinter[msg.sender], "Unauthorized");
        _mint(_account, _amount);
    }

    /**
     * @dev Burn existing tokens of an account.
     * @param _account The address to burn from
     * @param _amount The amount of tokens to burn
     */
    function burn(address _account, uint256 _amount) external override {
        require(isMinter[msg.sender], "Unauthorized");
        _burn(_account, _amount);
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
    ) external override {
        require(_deadline >= block.timestamp, "Permit expired");

        bytes32 digest =
            keccak256(
                abi.encode(PERMIT_TYPEHASH, _owner, _spender, _amount, nonces[_owner], _deadline)
            );

        // We allow either L1 or L2 signatures
        require(
            _verify(DOMAIN_SEPARATOR_L1, digest, _owner, _v, _r, _s) ||
                _verify(DOMAIN_SEPARATOR_L2, digest, _owner, _v, _r, _s),
            "Invalid signature"
        );
        nonces[_owner]++;

        _approve(_owner, _spender, _amount);
    }

    /**
     * @dev Allows for approving tokens and calling an external contract in a
     *      single transaction. The called contract must support have support
     *      for a custom calldata format (with the sender of the transaction
     *      appended at the end of the calldata).
     * @param _owner The approver of the tokens
     * @param _spender The spender of the tokens
     * @param _amount Approved amount
     * @param _callTo Contract address to call
     * @param _callData Calldata of the contract call
     * @param _deadline Approval deadline
     * @param _v Part of signature
     * @param _r Part of signature
     * @param _s Part of signature
     */
    function permitAndCall(
        address _owner,
        address _spender,
        uint256 _amount,
        address _callTo,
        bytes memory _callData,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public returns (bytes memory) {
        require(_deadline >= block.timestamp, "Permit expired");

        // Don't pass the nonce directly (`nonces[_owner]`) to avoid 'Stack too deep' errors
        uint256 nonce = nonces[_owner];
        bytes32 digest =
            keccak256(
                abi.encode(
                    PERMIT_AND_CALL_TYPEHASH,
                    _owner,
                    _spender,
                    _amount,
                    _callTo,
                    keccak256(_callData),
                    nonce,
                    _deadline
                )
            );

        // We allow either L1 or L2 signatures
        require(
            _verify(DOMAIN_SEPARATOR_L1, digest, _owner, _v, _r, _s) ||
                _verify(DOMAIN_SEPARATOR_L2, digest, _owner, _v, _r, _s),
            "Invalid signature"
        );
        nonces[_owner]++;

        _approve(_owner, _spender, _amount);

        // Pass `_owner` at the end of the calldata
        (bool success, bytes memory returnData) =
            // solhint-disable-next-line avoid-low-level-calls
            _callTo.call(abi.encodePacked(_callData, _owner));
        require(success, "Unsuccessfull call");

        return returnData;
    }

    /***************************************
                    HELPERS
    ****************************************/

    function _verify(
        bytes32 _domainSeparator,
        bytes32 _digest,
        address _owner,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal pure returns (bool) {
        address signer = ecrecover(_toEIP712Digest(_domainSeparator, _digest), _v, _r, _s);
        return signer != address(0) && signer == _owner;
    }

    function _toEIP712Digest(bytes32 _domainSeparator, bytes32 _messageDigest)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator, _messageDigest));
    }

    function _getChainId() internal pure returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}
