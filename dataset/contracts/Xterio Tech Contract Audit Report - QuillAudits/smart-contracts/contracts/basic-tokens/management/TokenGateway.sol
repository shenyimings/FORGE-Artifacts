// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../interfaces/IGateway.sol";
import "../interfaces/IGatewayGuarded.sol";

import "../interfaces/IBasicERC721.sol";
import "../interfaces/IBasicERC1155.sol";
import "../interfaces/IBasicERC20.sol";
import "../interfaces/IPausable.sol";

import "../interfaces/IGatewayGuardedOwnable.sol";

contract TokenGateway is Initializable, AccessControl, IGateway {
    /********************************************************************
     *                          Role System                             *
     ********************************************************************/

    /**
     * The role responsible for setting manager of contracts.
     * @notice Can only call `setManagerOf`.
     */
    bytes32 public constant GATEWAY_MANAGER_ROLE =
        keccak256("GATEWAY_MANAGER_ROLE");

    /**
     * Store a one-to-one relationship between a certain nft contract
     * and a manager address.
     */
    mapping(address => address) public override nftManager;
    mapping(address => address) nftPreviousManager;
    mapping(address => uint256) nftManagerGraceTimeStart;

    /**
     * Store whitelist addresses that may operate with NFTs without approval
     */
    mapping(address => bool) public override operatorWhitelist;

    event TransferGatewayOwnership(
        address indexed previousGatewayManager,
        address indexed newGatewayManager
    );

    event AssignManager(
        address indexed assigner,
        address indexed contractAddress,
        address previousContractManager,
        address indexed newContractManager
    );

    event AddOperatorWhitelist(address indexed operator);

    event RemoveOperatorWhitelist(address indexed operator);

    modifier onlyManagerAndWhitelist(address _nftContract) {
        require(
            isInManagement(msg.sender, _nftContract) ||
                operatorWhitelist[msg.sender],
            "TokenGateway: caller is not manager of the nft contract and is not in whitelist"
        );
        _;
    }

    /**
     * NFTGateway is an upgradeable function.
     * When initializing the gateway, a gateway admin address
     * should be designated.
     */
    function initialize(address _gatewayAdmin) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _gatewayAdmin);
    }

    /********************************************************************
     *               Interfaces exposed to nft managers                 *
     ********************************************************************/

    function resetOwner(address _nftContract, address _newOwner)
        external
        onlyManagerAndWhitelist(_nftContract)
    {
        IGatewayGuardedOwnable(_nftContract).resetOwner(_newOwner);
    }

    /**
     * Call `mint` function on a BasicERC721 contract through gateway
     */
    function ERC721_mint(
        address _nftContract,
        address _recipient,
        uint256 _tokenId
    ) external override onlyManagerAndWhitelist(_nftContract) {
        IBasicERC721(_nftContract).mint(_recipient, _tokenId);
    }

    /**
     * Call `mint` function on a BasicERC721 contract through gateway
     */
    function ERC721_mintBatch(
        address _nftContract,
        address _recipient,
        uint256[] calldata _tokenId
    ) external override onlyManagerAndWhitelist(_nftContract) {
        IBasicERC721(_nftContract).mintBatch(_recipient, _tokenId);
    }

    /**
     * Call `setURI` function on a BasicERC721 contract through gateway
     */
    function ERC721_setURI(address _nftContract, string calldata _newURI)
        external
        override
        onlyManagerAndWhitelist(_nftContract)
    {
        IBasicERC721(_nftContract).setURI(_newURI);
    }

    /**
     * Call `mint` function on a BasicERC1155 contract through gateway
     */
    function ERC1155_mint(
        address _nftContract,
        address _account,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) external override onlyManagerAndWhitelist(_nftContract) {
        IBasicERC1155(_nftContract).mint(_account, _id, _amount, _data);
    }

    /**
     * Call `mintBatch` function on a BasicERC1155 contract through gateway
     */
    function ERC1155_mintBatch(
        address _nftContract,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external override onlyManagerAndWhitelist(_nftContract) {
        IBasicERC1155(_nftContract).mintBatch(_to, _ids, _amounts, _data);
    }

    /**
     * Call `setURI` function on a BasicERC1155 contract through gateway
     */
    function ERC1155_setURI(address _nftContract, string calldata _newuri)
        external
        override
        onlyManagerAndWhitelist(_nftContract)
    {
        IBasicERC1155(_nftContract).setURI(_newuri);
    }

    function ERC20_mint(
        address _erc20Contract,
        address _recipient,
        uint256 _amount
    ) external override onlyManagerAndWhitelist(_erc20Contract) {
        IBasicERC20(_erc20Contract).mint(_recipient, _amount);
    }

    function pause(address _contract)
        external
        override
        onlyManagerAndWhitelist(_contract)
    {
        IPausable(_contract).pause();
    }

    function unpause(address _contract)
        external
        override
        onlyManagerAndWhitelist(_contract)
    {
        IPausable(_contract).unpause();
    }

    /********************************************************************
     *                       Manage nft managers                        *
     ********************************************************************/

    /**
     * Set the manager of a certain NFT contract.
     *
     * Note The previous manager of the nft still has access to management during
     * the grace period, which spans 1 day.
     */
    function setManagerOf(address _nftContract, address _manager)
        external
        override
        onlyRole(GATEWAY_MANAGER_ROLE)
    {
        emit AssignManager(
            msg.sender,
            _nftContract,
            nftManager[_nftContract],
            _manager
        );

        nftPreviousManager[_nftContract] = nftManager[_nftContract];
        nftManagerGraceTimeStart[_nftContract] = block.timestamp;

        nftManager[_nftContract] = _manager;
    }

    /********************************************************************
     *                      Admin-only functions                        *
     ********************************************************************/

    /**
     * Add an nft operator to the whitelist
     */
    function addOperatorWhitelist(address _operator)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // Check if the _operator is a contract address
        require(
            AddressUpgradeable.isContract(_operator),
            "TokenGateway: operator is not contract"
        );

        operatorWhitelist[_operator] = true;

        emit AddOperatorWhitelist(_operator);
    }

    /**
     * Remove an nft operator from the whitelist
     */
    function removeOperatorWhitelist(address _operator)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        operatorWhitelist[_operator] = false;

        emit RemoveOperatorWhitelist(_operator);
    }

    /**
     * Add a manager
     * @notice Only the admin should call this function.
     */
    function addManager(address _manager)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(GATEWAY_MANAGER_ROLE, _manager);
    }

    /**
     * Remove a manager
     * @notice Only the admin should call this function.
     */
    function removeManager(address _manager)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(GATEWAY_MANAGER_ROLE, _manager);
    }

    /**
     * This is the only way of changing the gateway of a certain contract.
     * @notice Should be rarely called.
     */
    function setGatewayOf(address _nftContract, address _newGateway)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _newGateway != address(this),
            "TokenGateway: new gateway should be different than the current one"
        );

        nftManager[_nftContract] = address(0);
        nftPreviousManager[_nftContract] = address(0);
        IGatewayGuarded(_nftContract).setGateway(_newGateway);
    }

    /**
     * Change the gateway manager address.
     * @notice Should be rarely called.
     */
    function transferGatewayOwnership(address _gatewayAdmin)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _gatewayAdmin != msg.sender,
            "TokenGateway: new gateway admin should be different than the current one"
        );

        emit TransferGatewayOwnership(msg.sender, _gatewayAdmin);

        // The new gateway manager picks up his role.
        _grantRole(DEFAULT_ADMIN_ROLE, _gatewayAdmin);

        // The previous gateway manager renounces his big role.
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /********************************************************************
     *                        Helper functions                          *
     ********************************************************************/

    /**
     * @dev Check if address `_x` is in management.
     * @notice If `_x` is the previous manager and the grace period has not
     * passed, still returns true.
     */
    function isInManagement(address _x, address _nftContract)
        public
        view
        returns (bool)
    {
        return
            _x == nftManager[_nftContract] ||
            (_x == nftPreviousManager[_nftContract] &&
                block.timestamp <
                nftManagerGraceTimeStart[_nftContract] + 1 days);
    }
}
