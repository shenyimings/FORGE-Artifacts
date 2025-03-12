// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/// @title MoiIncentiveContract - MOI token allocation management for all testnets
/// @author MOI Network LLC
/// @notice Operated by MOI Network LLC to manage and track allocations of all testnet users
contract MoiIncentiveContract {
    address private _owner; // _owner is the contract owner, also known as the "deployer"

    struct AllocationClass {
        bytes1 index; // Index is the primary identifier for the allocation class
        string name; // Name is used to identify different categories of allocation class
        uint256 capacity; // Capacity represents the maximum tokens allotted to the allocation class
        uint256 allocated; // Allocated keeps track of total number of tokens already allocated in the class
        bytes metadata; // Metadata consists of extra information passed while creating or updating the allocation class
        bool isActive; // IsActive is used as a status check for the allocation class before operating on it
    }

    bytes1[] private allocationClassIndices; // allocationClassIndices records the indices of all allocation classes

    uint256 private allocationsRateLimit; // allocationsRateLimit is used to control the size of allocate() calls

    mapping(bytes1 => AllocationClass) private indexToAllocationClass; // indexToAllocationClass mapping maps indexes to respective allocation classes

    mapping(string => mapping(bytes1 => uint256)) private allocations; // allocations tracks allocation for each wallet across allocation classes

    mapping(string => mapping(bytes1 => string[])) private allocationProofs; // allocationProofs maintains proof records for every single allocation made, per user, per category

    // NewUserInAllocationClass is triggered when a new user is allocated tokens and added to the class
    event NewUserInAllocationClass(
        string indexed user,
        bytes1 indexed allocationClassType,
        uint256 time
    );

    // AddOrUpdateAllocationClass is triggered when a new AllocationClass is added or an existing one is updated
    event AllocationClassCreatedOrUpdated(
        bytes1 allocationClassIndex,
        string eventMessage,
        uint256 time
    );

    // AllocationSuccessful is emitted when a user is given a token allocation under an index
    event AllocationSuccessful(
        string indexed user,
        uint256 amountAllocated,
        bytes1 index,
        uint256 time
    );

    error errorUnauthorized(string message);
    error errorInvalidNewCapacity(string message);
    error errorAllocationClassInactive(string message);
    error errorMismatchInUserAndTokenAmountLength(string message);
    error errorMismatchInTokenAmountAndProofLength(string message);
    error errorUserListLengthOverRateLimit(string message);
    error errorAllocationClassCapacityReached(string message);
    error errorInvalidAllocationClass(string message);
    error errorInvalidUserIdOrAllocationClassIndex(string message);

    /**
     * @dev Throws if called by any other account other than the smart contract owner.
     */
    modifier onlyOwner() {
        if (_owner != msg.sender) {
            revert errorUnauthorized("You do not have access to make this call. Owners only!");
        }
        _;
    }

    constructor() {
        _owner = msg.sender;
        allocationsRateLimit = 1;
        createAllocationClass("Indus", 1, "INDUS Airdrop on BABYLON, May 2023");
    }

    /* Setters */
    // Allocation Class

    /**
     * @dev Create a new instance of AllocationClass struct
     * @param _className is the Name assigned to the new AllocationClass
     * @param _capacity is the initial cap set on the allocations that can be made in AllocationClass
     * @param _metadata provides additional context as to why this new AllocationClass was created
     */
    function createAllocationClass(
        string memory _className,
        uint256 _capacity,
        bytes memory _metadata
    ) public onlyOwner {
        bytes1 newIndex = bytes1(uint8(allocationClassIndices.length));
        AllocationClass memory newAllocationClass = AllocationClass(
            newIndex,
            _className,
            _capacity,
            0, /// @dev Allocated is set to zero as this is a new Asset Class creation without any activity
            _metadata,
            true
        );

        allocationClassIndices.push(newIndex);
        indexToAllocationClass[newIndex] = newAllocationClass;

        emit AllocationClassCreatedOrUpdated(
            newIndex,
            string(abi.encodePacked("AllocationClass created: ", _className)),
            block.timestamp
        );
    }

    /**
     * @dev Updates token capacity of a given AllocationClass
     * @param _index refers to the index of the AllocationClass whose capacity must be updated
     * @param _newCapacity is the new value that replaces the current AllocationClass.capacity
     */
    function updateCapacity(
        bytes1 _index,
        uint256 _newCapacity
    ) public onlyOwner {
        AllocationClass memory theAllocationClass = getAllocationClass(_index);

        if (_newCapacity < theAllocationClass.capacity) {
            revert errorInvalidNewCapacity("Make sure the new capacity is always larger than the old one.");
        }

        theAllocationClass.capacity = _newCapacity;
        indexToAllocationClass[_index] = theAllocationClass;

        emit AllocationClassCreatedOrUpdated(
            _index,
            string(abi.encodePacked("AllocationClass updated with new capacity: ", _newCapacity)),
            block.timestamp
        );
    }

    /**
     * @dev Updates the operating status of a given AllocationClass
     * @param _index refers to the index of the AllocationClass whose capacity must be updated
     * @param _newStatus is the new value that replaces the current AllocationClass.IsActive
     */
    function updateStatus(
        bytes1 _index,
        bool _newStatus
    ) public onlyOwner {
        AllocationClass memory theAllocationClass = getAllocationClass(_index);

        theAllocationClass.isActive = _newStatus;
        indexToAllocationClass[_index] = theAllocationClass;

        emit AllocationClassCreatedOrUpdated(
            _index,
            string(abi.encodePacked("AllocationClass status updated: ", _newStatus)),
            block.timestamp
        );
    }

    /**
     * @dev Updates the metadata of a given AllocationClass
     * @param _index refers to the index of the AllocationClass whose capacity must be updated
     * @param _newMetadata is the new value that replaces the current AllocationClass.Metadata
     */
    function updateMetadata(
        bytes1 _index,
        bytes memory _newMetadata
    ) public onlyOwner {
        AllocationClass memory theAllocationClass = getAllocationClass(_index);

        theAllocationClass.metadata = _newMetadata;
        indexToAllocationClass[_index] = theAllocationClass;

        emit AllocationClassCreatedOrUpdated(
            _index,
            string(abi.encodePacked("AllocationClass metadata updated: ", _newMetadata)),
            block.timestamp
        );
    }

    /**
     * @dev Update the rate limit on how many allocations can be made at once in the allocate() call
     * @param _newRateLimit replaces the current value held at the global variable `allocationsRateLimit`
     */
    function updateAllocationsRateLimit(uint256 _newRateLimit) public onlyOwner {
        allocationsRateLimit = _newRateLimit;
    }

    /**
     * @dev Allocates a corresponding amount of tokens to a list of users in a given AllocationClass
     * @param _index refers to the index of the AllocationClass whose capacity must be updated
     * @param _users is a list of MOI ID usernames or wallet addresses who will be assigned tokens
     * @param _amounts is a list of token amounts that must be credited to users in _users list in corresponding order
     */
    function allocate(
        bytes1 _index,
        string[] memory _users,
        uint256[] memory _amounts,
        string[] memory _allocationProofs
    ) public onlyOwner {
        AllocationClass memory theAllocationClass = getAllocationClass(_index);

        if (!theAllocationClass.isActive) {
            revert errorAllocationClassInactive("Owner set this allocation class to inactive");
        }

        if (_users.length != _amounts.length) {
            revert errorMismatchInUserAndTokenAmountLength("User list and token amounts list length do not match");
        }

        if (_amounts.length != _allocationProofs.length) {
            revert errorMismatchInTokenAmountAndProofLength("Token amounts list and proofs list length do not match");
        }

        if (_users.length > allocationsRateLimit) {
            revert errorUserListLengthOverRateLimit("User list length exceeds the rate limit");
        }

        for (uint i = 0; i < _users.length; i++) {
            if (theAllocationClass.capacity < indexToAllocationClass[_index].allocated+_amounts[i]) {
                revert errorAllocationClassCapacityReached("Capacity has been reached. No more allocations!");
            }
            uint256 currentUserAllocations = allocations[_users[i]][_index];

            allocations[_users[i]][_index] = currentUserAllocations + _amounts[i];
            indexToAllocationClass[_index].allocated += _amounts[i];

            allocationProofs[_users[i]][_index].push(_allocationProofs[i]);

            if (currentUserAllocations == 0) {
                emit NewUserInAllocationClass(
                    _users[i],
                    _index,
                    block.timestamp
                );
            }

            emit AllocationSuccessful(_users[i], _amounts[i], _index, block.timestamp);
        }
    }

    /* Getters */
    // @returns Owner of the Contract
    function getOwner() public view returns (address) {
        return _owner;
    }

    // @returns Rate Limit of number of allocations that can be made in one allocate() call
    function getAllocLimitPerCall() public view returns (uint256) {
        return allocationsRateLimit;
    }

    /**
    * @dev getAllocationClass returns the AllocationClass by its index
    * @param _index is the index of the AllocationClass which must be returned
    * @return _assetClass is fetched from indexToAllocationClass and returned
    */
    function getAllocationClass(bytes1 _index) public view returns (AllocationClass memory _assetClass) {
        _assetClass = indexToAllocationClass[_index];
        if (isStringsEqual(_assetClass.name, "")) {
            revert errorInvalidAllocationClass("Invalid Allocation class");
        }
    }

    /**
    * @dev getAllocationProofsOf returns all the proofs recorded for a given user
    * @param _user is the address of the user whose proofs must be returned
    * @param _index is the allocation class from which the proof of allocation must be returned
    * @return _proofs is fetched from allocationProofs and returned
    */
    function getAllocationProofsOf(string memory _user, bytes1 _index) public view returns (string[] memory _proofs) {
        _proofs = allocationProofs[_user][_index];
        if (_proofs.length < 0) {
            revert errorInvalidUserIdOrAllocationClassIndex("Invalid User ID or Allocation Class Index");
        }
    }

    /**
    * @dev getUserAllocations returns the AllocationClass by its index
    * @param _user is the MOI ID username or the wallet address of the user
    * @return user's allocations across all AllocationClasses in correspondingly ordered slices of index and amount
    */
    function getUserAllocations(
        string memory _user
    ) public view returns (bytes1[] memory, uint256[] memory) {
        uint256[] memory allocationsPerIndex = new uint256[](allocationClassIndices.length);

        for (uint8 i = 0; i < uint8(allocationClassIndices.length); i++) {
            allocationsPerIndex[i] = allocations[_user][allocationClassIndices[i]];
        }

        return (allocationClassIndices, allocationsPerIndex);
    }

    /**
    * @dev getUserAllocations adds up everything allocated till date in each AllocationClass a.k.a. total token count
    * @return total number of tokens ever allocated in each AllocationClass and returns a split array with order
    */
    function getTotalTokensAllocated() public view returns (bytes1[] memory, uint256[] memory)
    {
        uint256[] memory allocatedTokens = new uint256[](allocationClassIndices.length);

        for (uint8 i = 0; i < uint8(allocationClassIndices.length); i++) {
            //            allocatedTokens[i] = tokensAllocated[allocationClassIndices[i]];
            allocatedTokens[i] = indexToAllocationClass[allocationClassIndices[i]].allocated;
        }
        return (allocationClassIndices, allocatedTokens);
    }

    /**
    * @dev isStringEqual compares two string literals by hashing and comparing them
    * @param _str1 is the first string to be compared with the second string
    * @param _str2 is the second string to be compared with the first string
    * @return returns true is both strings have same hashes, else returns false
    */
    function isStringsEqual(
        string memory _str1,
        string memory _str2
    ) internal pure returns (bool) {
        return keccak256(abi.encodePacked(_str1)) == keccak256(abi.encodePacked(_str2));
    }
}
