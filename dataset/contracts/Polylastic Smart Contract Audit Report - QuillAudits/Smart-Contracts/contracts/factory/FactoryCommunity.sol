// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../partnerProgram/IPartnerProgram.sol";
import "contracts/index/IIndex.sol";
import "./IFactory.sol";
import "../index/IIndexCommunity.sol";

contract FactoryCommunity is AccessControl, IFactory {
    bytes32 public constant DAO_COMMUNITY_ROLE = keccak256("DAO_ROLE");
    bytes32 public constant DAO_ADMIN_ROLE = keccak256("DAO_ADMIN_ROLE");

    // address of the implementation contract
    address private _indexMaster;
    address private _DAOAdminAddress;
    address private _DAOCommAddress;
    address private _validator;
    address[] private _indexes;
    address private _USD;
    address private _adapter;
    address private _tresuare;
    uint256 private _rebalancePeriod;
    IPartnerProgram private _ipartnerProgram;

    constructor(
        address implementation,
        address DAOAdminAddr,
        address DAOCommAddr,
        address validator,
        address USD,
        address adapter,
        uint256 rebalancePeriod,
        address tresuare,
        address partnerProgram
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DAO_COMMUNITY_ROLE, DAOCommAddr);

        _indexMaster = implementation;
        _DAOAdminAddress = DAOAdminAddr;
        _DAOCommAddress = DAOCommAddr;
        _validator = validator;
        _USD = USD;
        _adapter = adapter;
        _rebalancePeriod = rebalancePeriod;
        _tresuare = tresuare;
        _ipartnerProgram = IPartnerProgram(partnerProgram);
    }

    function mint(
        uint256 startPrice,
        address[] memory newAssets,
        string memory nameIndex
    ) external onlyRole(DAO_COMMUNITY_ROLE) {
        address instance = Clones.clone(_indexMaster);
        IIndexCommunity(instance).initialize(
            _DAOAdminAddress,
            _validator,
            _USD,
            _adapter,
            startPrice,
            _rebalancePeriod,
            newAssets,
            _tresuare,
            address(_ipartnerProgram),
            _DAOCommAddress,
            nameIndex
        );
        _indexes.push(instance);
        _ipartnerProgram.setupRoleIndex(instance);

        emit Mint(instance);
    }

    function changeIndexMaster(
        address newIndexMaster
    ) external onlyRole(DAO_ADMIN_ROLE) {
        emit ChangeIndexMaster(_indexMaster, newIndexMaster);
        _indexMaster = newIndexMaster;
    }

    function changeMainParam(
        address DAOAdminAddress,
        address DAOACommAddress,
        address validator,
        address USD,
        address adapter,
        address tresuare,
        uint256 rebalancePeriod
    ) external onlyRole(DAO_ADMIN_ROLE) {
        _DAOAdminAddress = DAOAdminAddress;
        _DAOCommAddress = DAOACommAddress;
        _validator = validator;
        _USD = USD;
        _adapter = adapter;
        _rebalancePeriod = rebalancePeriod;
        _tresuare = tresuare;

        emit ChangeMainParamCommunity(
            DAOAdminAddress,
            DAOACommAddress,
            validator,
            USD,
            adapter,
            tresuare,
            rebalancePeriod
        );
    }

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
            _DAOAdminAddress,
            _validator,
            _USD,
            _adapter,
            _tresuare,
            _rebalancePeriod,
            address(_ipartnerProgram)
        );
    }

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
