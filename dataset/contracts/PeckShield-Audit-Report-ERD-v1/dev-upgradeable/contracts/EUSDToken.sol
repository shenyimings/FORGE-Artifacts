// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./Dependencies/ERDMath.sol";
import "./Interfaces/IEUSDToken.sol";

/*
 *
 * --- Functionality added specific to the EUSDToken ---
 *
 * 1) Transfer protection: blacklist of addresses that are invalid recipients (i.e. core ERD contracts) in external
 * transfer() and transferFrom() calls. The purpose is to protect users from losing tokens by mistakenly sending EUSD directly to a ERD
 * core contract, when they should rather call the right function.
 *
 * 2) sendToPool() and returnFromPool(): functions callable only ERD core contracts, which move EUSD tokens between ERD <-> user.
 */

contract EUSDToken is ERC20Upgradeable, IEUSDToken {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    string internal constant _NAME = "EUSD Stablecoin";
    string internal constant _SYMBOL = "EUSD";
    string internal constant _VERSION = "1";
    uint8 internal constant _DECIMALS = 18;

    // --- Data for EIP2612 ---

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private constant _PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TYPE_HASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private _CACHED_DOMAIN_SEPARATOR;
    uint256 private _CACHED_CHAIN_ID;

    bytes32 private _HASHED_NAME;
    bytes32 private _HASHED_VERSION;

    mapping(address => uint256) private _nonces;

    // --- Addresses ---
    address public troveManagerAddress;
    address internal troveManagerLiquidationsAddress;
    address internal troveManagerRedemptionsAddress;
    address public stabilityPoolAddress;
    address public borrowerOperationsAddress;
    address public treasuryAddress;
    address public liquidityIncentiveAddress;

    // --- Events ---
    event TroveManagerAddressChanged(address _troveManagerAddress);
    event TroveManagerLiquidatorAddressChanged(
        address _troveManagerLiquidatorAddress
    );
    event TroveManagerRedemptionsAddressChanged(
        address _troveManagerRedemptionsAddress
    );
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);
    event BorrowerOperationsAddressChanged(
        address _newBorrowerOperationsAddress
    );
    event TreasuryAddressChanged(address _newTreasuryAddress);
    event LiquidityIncentiveAddressChanged(
        address _newLiquidityIncentiveAddress
    );

    function initialize(
        address _troveManagerAddress,
        address _troveManagerLiquidationsAddress,
        address _troveManagerRedemptionsAddress,
        address _stabilityPoolAddress,
        address _borrowerOperationsAddress,
        address _treasuryAddress,
        address _liquidityIncentiveAddress
    ) public initializer {
        __ERC20_init(_NAME, _SYMBOL);
        _requireIsContract(_troveManagerAddress);
        _requireIsContract(_troveManagerLiquidationsAddress);
        _requireIsContract(_troveManagerRedemptionsAddress);
        _requireIsContract(_stabilityPoolAddress);
        _requireIsContract(_borrowerOperationsAddress);
        _requireIsContract(_treasuryAddress);
        _requireIsContract(_liquidityIncentiveAddress);

        troveManagerAddress = _troveManagerAddress;
        emit TroveManagerAddressChanged(_troveManagerAddress);

        troveManagerLiquidationsAddress = _troveManagerLiquidationsAddress;
        emit TroveManagerLiquidatorAddressChanged(
            _troveManagerLiquidationsAddress
        );

        troveManagerRedemptionsAddress = _troveManagerRedemptionsAddress;
        emit TroveManagerRedemptionsAddressChanged(
            _troveManagerRedemptionsAddress
        );

        stabilityPoolAddress = _stabilityPoolAddress;
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);

        borrowerOperationsAddress = _borrowerOperationsAddress;
        emit BorrowerOperationsAddressChanged(_borrowerOperationsAddress);

        treasuryAddress = _treasuryAddress;
        emit TreasuryAddressChanged(_treasuryAddress);

        liquidityIncentiveAddress = _liquidityIncentiveAddress;
        emit LiquidityIncentiveAddressChanged(_liquidityIncentiveAddress);

        bytes32 hashedName = keccak256(bytes(_NAME));
        bytes32 hashedVersion = keccak256(bytes(_VERSION));

        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = _chainID();
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(
            _TYPE_HASH,
            hashedName,
            hashedVersion
        );
    }

    // --- Functions for intra-ERD calls ---

    function mint(address _account, uint256 _amount) external override {
        _requireCallerIsBorrowerOperations();
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override {
        _requireCallerIsBOorTroveMorSP();
        _burn(_account, _amount);
    }

    function mintToTreasury(uint256 _amount, uint256 _factor) external override {
        _requireCallerIsTroveMorBO();
        uint256 incentiveFee = _amount.mul(_factor).div(ERDMath.DECIMAL_PRECISION);
        _mint(liquidityIncentiveAddress, incentiveFee);
        _mint(treasuryAddress, _amount.sub(incentiveFee));
    }

    function sendToPool(
        address _sender,
        address _poolAddress,
        uint256 _amount
    ) external override {
        _requireCallerIsStabilityPool();
        _transfer(_sender, _poolAddress, _amount);
    }

    function returnFromPool(
        address _poolAddress,
        address _receiver,
        uint256 _amount
    ) external override {
        _requireCallerIsTMLorSP();
        _transfer(_poolAddress, _receiver, _amount);
    }

    // --- External functions ---

    function transfer(
        address recipient,
        uint256 amount
    ) public override(IERC20Upgradeable, ERC20Upgradeable) returns (bool) {
        _requireValidRecipient(recipient);
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override(IERC20Upgradeable, ERC20Upgradeable) returns (bool) {
        _requireValidRecipient(recipient);
        super.transferFrom(sender, recipient, amount);
        return true;
    }

    // --- EIP 2612 Functionality ---

    function DOMAIN_SEPARATOR() public view override returns (bytes32) {
        if (_chainID() == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return
                _buildDomainSeparator(
                    _TYPE_HASH,
                    _HASHED_NAME,
                    _HASHED_VERSION
                );
        }
    }

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(deadline >= block.timestamp, "EUSD: expired deadline");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        _PERMIT_TYPEHASH,
                        owner,
                        spender,
                        amount,
                        _nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner, "EUSD: invalid signature");
        _approve(owner, spender, amount);
    }

    function nonces(address owner) external view override returns (uint256) {
        // FOR EIP 2612
        return _nonces[owner];
    }

    // --- Internal operations ---

    function _chainID() private view returns (uint256 chainID) {
        assembly {
            chainID := chainid()
        }
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 _name,
        bytes32 _version
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(typeHash, _name, _version, _chainID(), address(this))
            );
    }

    // --- Internal operations ---
    // Warning: sanity checks (for sender and recipient) should have been done before calling these internal functions

    // --- 'require' functions ---

    function _requireIsContract(address _contract) internal view {
        require(_contract.isContract(), "EUSD: Contract check error");
    }

    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && _recipient != address(this),
            "EUSD: Cannot transfer tokens directly to the EUSD token contract or the zero address"
        );
        require(
            _recipient != stabilityPoolAddress &&
                _recipient != troveManagerAddress &&
                _recipient != borrowerOperationsAddress,
            "EUSD: Cannot transfer tokens directly to the StabilityPool, TroveManager or BorrowerOps"
        );
    }

    function _requireCallerIsBorrowerOperations() internal view {
        require(
            msg.sender == borrowerOperationsAddress,
            "EUSDToken: Caller is not BorrowerOperations"
        );
    }

    function _requireCallerIsTroveMorBO() internal view {
        require(
            msg.sender == troveManagerAddress || msg.sender == borrowerOperationsAddress,
            "EUSD: Caller is not TroveManager or BO"
        );
    }

    function _requireCallerIsBOorTroveMorSP() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
                msg.sender == troveManagerAddress ||
                msg.sender == stabilityPoolAddress ||
                msg.sender == troveManagerRedemptionsAddress,
            "EUSD: Caller is neither BorrowerOperations nor TroveManager nor StabilityPool"
        );
    }

    function _requireCallerIsStabilityPool() internal view {
        require(
            msg.sender == stabilityPoolAddress,
            "EUSD: Caller is not the StabilityPool"
        );
    }

    function _requireCallerIsTMLorSP() internal view {
        require(
            msg.sender == troveManagerLiquidationsAddress ||
                msg.sender == stabilityPoolAddress,
            "EUSD: Caller is neither TroveManager nor StabilityPool"
        );
    }

    // --- Optional functions ---

    function name() public pure override returns (string memory) {
        return _NAME;
    }

    function symbol() public pure override returns (string memory) {
        return _SYMBOL;
    }

    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }

    function version() external pure returns (string memory) {
        return _VERSION;
    }

    function permitTypeHash() external pure returns (bytes32) {
        return _PERMIT_TYPEHASH;
    }
}
