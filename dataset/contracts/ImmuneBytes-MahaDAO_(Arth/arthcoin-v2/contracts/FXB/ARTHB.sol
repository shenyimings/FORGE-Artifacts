// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import '../ERC20/ERC20.sol';
import '../ERC20/IERC20.sol';
import '../Math/SafeMath.sol';
import './ArthBondIssuer.sol';
import '../Common/Context.sol';
import '../ERC20/ERC20Custom.sol';
import '../Governance/AccessControl.sol';

/**
 *  Original code written by:
 *  - Travis Moore, Jason Huan, Same Kazemian, Sam Sun.
 */
contract ArthBond is ERC20Custom, AccessControl {
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    string public symbol;
    string public name;
    uint8 public constant override decimals = 18;
    address public ownerAddress;
    address public timelock_address; // Governance timelock address
    address public controller_address; // Controller contract to dynamically adjust system parameters automatically

    uint256 public constant genesis_supply = 100e18; // 2M ARTH (only for testing, genesis supply will be 5k on Mainnet). This is to help with establishing the Uniswap pools, as they need liquidity

    // The addresses in this array are added by the oracle and these contracts are able to mint arth
    address[] public bond_issuers_array;

    // Mapping is also used for faster verification
    mapping(address => bool) public bond_issuers;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;

    // Other variables
    address public DEFAULT_ADMIN_ADDRESS;

    /* ========== MODIFIERS ========== */

    modifier onlyIssuers() {
        require(
            bond_issuers[msg.sender] == true,
            'Only bond issuers can call this function'
        );
        _;
    }

    modifier onlyByOwnerControllerOrGovernance() {
        require(
            msg.sender == ownerAddress ||
                msg.sender == timelock_address ||
                msg.sender == controller_address,
            'You are not the owner, controller, or the governance timelock'
        );
        _;
    }

    modifier onlyByOwnerOrTimelock() {
        require(
            msg.sender == ownerAddress || msg.sender == timelock_address,
            'You are not the owner or the governance timelock'
        );
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(
        string memory _name,
        string memory _symbol,
        address _ownerAddress,
        address _timelock_address,
        address _controller_address
    ) {
        name = _name;
        symbol = _symbol;
        ownerAddress = _ownerAddress;
        timelock_address = _timelock_address;
        controller_address = _controller_address;

        _setupRole(DEFAULT_ADMIN_ROLE, _ownerAddress);
        DEFAULT_ADMIN_ADDRESS = _ownerAddress;
    }

    /* ========== VIEWS ========== */

    /* ========== PUBLIC FUNCTIONS ========== */

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Used by issuers when user mints
    function issuer_mint(address m_address, uint256 m_amount)
        external
        onlyIssuers
    {
        super._mint(m_address, m_amount);
        emit ARTHBMinted(msg.sender, m_address, m_amount);
    }

    // Used by issuers when user redeems
    function issuer_burn_from(address b_address, uint256 b_amount)
        external
        onlyIssuers
    {
        super._burnFrom(b_address, b_amount);
        emit ARTHBBurned(b_address, msg.sender, b_amount);
    }

    // Adds an issuer
    function addIssuer(address issuer_address)
        external
        onlyByOwnerControllerOrGovernance
    {
        require(
            bond_issuers[issuer_address] == false,
            'address already exists'
        );
        bond_issuers[issuer_address] = true;
        bond_issuers_array.push(issuer_address);
    }

    // Removes an issuer
    function removeIssuer(address issuer_address)
        external
        onlyByOwnerControllerOrGovernance
    {
        require(
            bond_issuers[issuer_address] == true,
            "address doesn't exist already"
        );

        // Delete from the mapping
        delete bond_issuers[issuer_address];

        // 'Delete' from the array by setting the address to 0x0
        for (uint256 i = 0; i < bond_issuers_array.length; i++) {
            if (bond_issuers_array[i] == issuer_address) {
                bond_issuers_array[i] = address(0); // This will leave a null in the array and keep the indices the same
                break;
            }
        }
    }

    /* ========== HIGHLY RESTRICTED EXTERNAL FUNCTIONS [Owner and Timelock only]  ========== */

    function setOwner(address _ownerAddress) external onlyByOwnerOrTimelock {
        ownerAddress = _ownerAddress;
    }

    function setTimelock(address new_timelock) external onlyByOwnerOrTimelock {
        timelock_address = new_timelock;
    }

    function setController(address _controller_address)
        external
        onlyByOwnerOrTimelock
    {
        controller_address = _controller_address;
    }

    /* ========== EVENTS ========== */

    // Track ARTHB burned
    event ARTHBBurned(address indexed from, address indexed to, uint256 amount);

    // Track ARTHB minted
    event ARTHBMinted(address indexed from, address indexed to, uint256 amount);
}
