// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "contracts/index/IIndex.sol";
import "../partnerProgram/IPartnerProgram.sol";
import "./IFactory.sol";
import "../index/IIndexAdmin.sol";

/// @title The factory contract issues indexes.
/// * The factory is made on the basis of EIP1167
contract FactoryAdmin is AccessControl, IFactory {
    bytes32 public constant DAO_ADMIN_ROLE = keccak256("DAO_ADMIN_ROLE");
    // stores index addresses
    address[] private _indexes;
    // address of the implementation contract
    address private _indexMaster;
    // address of the DAO contract
    address private _DAOAddress;
    address private _validator;
    address private _acceptToken;
    address private _adapter;
    address private _tresuare;
    uint256 private _rebalancePeriod;
    IPartnerProgram private _ipartnerProgram;

    /// @param implementation Implementation address (master index)
    /// @param DAOAddr DAO_ADMIN address
    /// @param validator  Validator address. Has access to rebalancing the index
    /// @param acceptToken token for payment
    /// @param adapter DEX adapter
    /// @param rebalancePeriod The time after which rebalancing occurs (seconds)
    /// @param tresuare Tresuare address
    /// @param partnerProgram PartnerProgram address
    constructor(
        address implementation,
        address DAOAddr,
        address validator,
        address acceptToken,
        address adapter,
        uint256 rebalancePeriod,
        address tresuare,
        address partnerProgram
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DAO_ADMIN_ROLE, DAOAddr);

        _indexMaster = implementation;
        _DAOAddress = DAOAddr;
        _validator = validator;
        _acceptToken = acceptToken;
        _adapter = adapter;
        _rebalancePeriod = rebalancePeriod;
        _tresuare = tresuare;
        _ipartnerProgram = IPartnerProgram(partnerProgram);
    }

    /// @notice Creating an index
    /// @param startPrice Start price
    /// @param newAssets Assets in the index
    /// @param nameIndex Index name
    function mint(
        uint256 startPrice,
        address[] memory newAssets,
        string memory nameIndex
    ) external onlyRole(DAO_ADMIN_ROLE) {
        address instance = Clones.clone(_indexMaster);
        IIndexAdmin(instance).initialize(
            _DAOAddress,
            _validator,
            _acceptToken,
            _adapter,
            startPrice,
            _rebalancePeriod,
            newAssets,
            _tresuare,
            address(_ipartnerProgram),
            nameIndex
        );
        _indexes.push(instance);
        _ipartnerProgram.setupRoleIndex(instance);

        emit Mint(instance);
    }

    /// @notice Change the implementation address
    function changeIndexMaster(
        address newIndexMaster
    ) external onlyRole(DAO_ADMIN_ROLE) {
        emit ChangeIndexMaster(_indexMaster, newIndexMaster);
        _indexMaster = newIndexMaster;
    }

    /// @notice Change the main factory parameters
    /// @param DAOAddress DAO_ADMIN address
    /// @param validator  Validator address. Has access to rebalancing the index
    /// @param acceptToken token for payment
    /// @param adapter DEX adapter
    /// @param tresuare Tresuare address
    /// @param rebalancePeriod The time after which rebalancing occurs (seconds)
    function changeMainParam(
        address DAOAddress,
        address validator,
        address acceptToken,
        address adapter,
        address tresuare,
        uint256 rebalancePeriod
    ) external onlyRole(DAO_ADMIN_ROLE) {
        _DAOAddress = DAOAddress;
        _validator = validator;
        _acceptToken = acceptToken;
        _adapter = adapter;
        _rebalancePeriod = rebalancePeriod;
        _tresuare = tresuare;

        emit ChangeMainParam(
            DAOAddress,
            validator,
            acceptToken,
            adapter,
            tresuare,
            rebalancePeriod
        );
    }

    /// @notice Return the main parameters
    function getMainParam()
        external
        view
        returns (
            address indexMaster,
            address DAOAddress,
            address validator,
            address USD,
            address adapter,
            address tresuare,
            uint256 rebalancePeriod,
            address ipartnerProgram
        )
    {
        return (
            _indexMaster,
            _DAOAddress,
            _validator,
            _acceptToken,
            _adapter,
            _tresuare,
            _rebalancePeriod,
            address(_ipartnerProgram)
        );
    }

    /// @notice Return a list of indexes created through the factory
    function getIndexes() external view returns (address[] memory) {
        return _indexes;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IFactory).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
