//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Admin {
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    bytes32 public adminChangeKey;
    address public rootAdmin;
    mapping(address => bool) public superAdmin;
    mapping(address => bool) public admin;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

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
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, "MoonShotAdmin", _keyData));
        require(verify(adminChangeKey, leaf, merkleProof), "Invalid proof.");

        rootAdmin = _newAdmin;
        adminChangeKey = _newRootKey;
    }

    constructor(address _root, bytes32 _adminChangeKey) public {
        rootAdmin = _root;
        adminChangeKey = _adminChangeKey;
    }

    modifier onlySuperAdmin() {
        require(isSuperAdmin(msg.sender), "Restricted to super admins");
        _;
    }

    modifier onlySuperAdminOrAdmin() {
        require(isSuperAdmin(msg.sender) || isAdmin(msg.sender), "Restricted to super admins or admins");
        _;
    }

    function isSuperAdmin(address _addr) public view returns (bool) {
        return (superAdmin[_addr] == true);
    }

    function addSuperAdmin(address _addr) public {
        require(msg.sender == rootAdmin, "Only Root can add super admin");
        superAdmin[_addr] = true;
        emit RoleGranted(SUPER_ADMIN_ROLE, _addr, msg.sender);
    }

    function revokeSuperAdmin(address _addr) public {
        require(msg.sender == rootAdmin, "Only Root can add super admin");
        superAdmin[_addr] = false;
        emit RoleRevoked(SUPER_ADMIN_ROLE, _addr, msg.sender);
    }

    function isAdmin(address _addr) public view returns (bool) {
        return (admin[_addr] == true);
    }

    function addAdmin(address _addr) public onlySuperAdmin {
        admin[_addr] = true;
        emit RoleGranted(ADMIN_ROLE, _addr, msg.sender);
    }

    function revokeAdmin(address _addr) public onlySuperAdminOrAdmin {
        admin[_addr] = false;
        emit RoleRevoked(ADMIN_ROLE, _addr, msg.sender);
    }
}