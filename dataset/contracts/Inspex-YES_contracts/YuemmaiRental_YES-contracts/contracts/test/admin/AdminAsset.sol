//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AdminAsset {
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public adminChangeKey;
    address public rootAdmin;
    
    mapping(address => mapping(string => bool)) public superAdmin;
    mapping(address => bool) public admin;
    mapping(address => string) superAdminToken;
    mapping(string => bool) public tokenSetAdmin;
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    
    modifier onlyRootAdmin() {
        require(msg.sender == rootAdmin, "Only Root can add super admin");
        _;
    }
    
    constructor(address _root, bytes32 _adminChangeKey) public {
        rootAdmin = _root;
        adminChangeKey = _adminChangeKey;
    }
    
    function verify(
        bytes32 root,
        bytes32 leaf,
        bytes32[] memory proof
    ) public pure returns (bool) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
    
    
    function changeRoot(
        address _newAdmin,
        bytes32 _keyData,
        bytes32[] memory merkleProof,
        bytes32 _newRootKey
    ) public {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, "BitkubChainAdmin", _keyData));
        require(verify(adminChangeKey, leaf, merkleProof), "Invalid proof.");
        rootAdmin = _newAdmin;
        adminChangeKey = _newRootKey;
    }
    
    
    function getSuperAdminToken(address _addr) external onlyRootAdmin view returns(string memory _token) {
        return superAdminToken[_addr];
    }
    
    function isSuperAdmin(address _addr,string calldata _token) external view returns (bool) {
        return (superAdmin[_addr][_token] == true);
    }
    
    function addSuperAdmin(address _addr, string calldata _token) external onlyRootAdmin {
        require(admin[_addr] == false && tokenSetAdmin[_token] == false, "Already set admin");
        superAdmin[_addr][_token] = true;
        superAdminToken[_addr] = _token;
        admin[_addr] = true;
        tokenSetAdmin[_token] = true;
        emit RoleGranted(SUPER_ADMIN_ROLE, _addr, msg.sender);
    }
    
    function revokeSuperAdmin(address _addr, string calldata _token) external onlyRootAdmin {
        superAdmin[_addr][_token] = false;
        admin[_addr] = false;
        tokenSetAdmin[_token] = false;
        emit RoleRevoked(SUPER_ADMIN_ROLE, _addr, msg.sender);
    }
}