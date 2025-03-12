// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "@openzeppelin/contracts/access/AccessControl.sol";



import "./TokenContract.sol"; 


contract TokenVesting is AccessControl {

    TokenContract public token;

    
    uint256 private constant MONTH = 30 days;
    uint256 private constant YEAR = 12 * MONTH;
    uint256 private constant DECIMAL_FACTOR = 10 ** 18;
    uint256 private constant SIZE_OF_ALLOCATIONS = 8;

    /// Constant public member variables
    uint256 public constant SUPPLY = 1000000000 * DECIMAL_FACTOR;
    uint256 public constant CANCELATION_PERIOD = 1 days;

    bytes32 public constant DISTRIBUTOR_ROLE = keccak256('DISTRIBUTOR_ROLE');
    bytes32 public constant SALE_ROLE = keccak256('SALE_ROLE');

    uint256 public availableAmount = SUPPLY;
    uint256 public grandTotalClaimed = 0;


    AllocationStructure[SIZE_OF_ALLOCATIONS] private _allocationTypes;
    mapping(address => Allocation) private _allocations;
    address[] private _allocatedAddresses;

    enum AllocationState {
        NotAllocated,
        Allocated,
        Canceled
    }


    enum AllocationType {
        Ecosystem,
        Advisors,
        Marketing,
        Partners,
        Presale,
        Private1,
        Private2,
        Public
    }


    struct AllocationStructure {
        uint256 lockupPeriod;
        uint256 vesting;
        uint256 totalAmount;
        uint256 availableAmount;
    }


        struct Allocation {
        AllocationType allocationType;          
        uint256 allocationTime;                 
        uint256 amount;                     
        uint256 amountClaimed;     
        AllocationState state; 
    }

    event NewAllocation(address indexed recipient, AllocationType indexed allocationType, uint256 amount);
    event TokenClaimed(address indexed recipient, AllocationType indexed allocationType, uint256 amountClaimed);
    event CancelAllocation(address indexed recipient);
    event BurnAllocation(AllocationType indexed allocationType, uint256 amount);



    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _initAllocationTypes();
        _checkAllocations();
        token = new TokenContract();
    }


    


   
    function setAllocation(address recipient_, uint256 amount_, AllocationType allocationType_) public {

        require(address(0x0) != recipient_, 'Recipient address cannot be 0x0');
        require(0 < amount_, 'Allocated amount must be greater than 0');
  
        _checkRole(_msgSender(), allocationType_);
        Allocation storage a = _allocations[recipient_];
        require(AllocationState.Allocated != a.state, 'Recipient already has allocation');
        if (AllocationState.NotAllocated == a.state) {
            _allocatedAddresses.push(recipient_);
        }
        a.allocationType = allocationType_;
        a.allocationTime = block.timestamp;
        a.amount = amount_;
        a.state = AllocationState.Allocated;
        _allocationTypes[uint256(allocationType_)].availableAmount -= amount_;
        availableAmount -= amount_;
        emit NewAllocation(recipient_, allocationType_, amount_);
    }

 
    /// Sets allocation for the given recipient with corresponding amount.
    function burn(AllocationType allocationType_) public {

        require(AllocationType.Presale == allocationType_
                || AllocationType.Private1 == allocationType_
                || AllocationType.Private2 == allocationType_
                || AllocationType.Public == allocationType_,
                "Burnable only Presale, Private1, Private2, Public");
        _checkRole(_msgSender(), allocationType_);
        uint256 i = uint256(allocationType_);
        if (0 != _allocationTypes[i].availableAmount) {
            token.burn(_allocationTypes[i].availableAmount);
            availableAmount -= _allocationTypes[i].availableAmount;
            emit BurnAllocation(allocationType_, _allocationTypes[i].availableAmount);
            _allocationTypes[i].availableAmount = 0;
        }
    }

    /// Cancels allocation for the given recipient
    function cancelAllocation(address recipient_) public {

        Allocation storage a = _allocations[recipient_];
        _checkRole(_msgSender(), a.allocationType);
        require(AllocationState.Allocated == a.state, 'There is no allocation');
        require(0 == a.amountClaimed, 'Cannot cancel allocation with claimed tokens');
        require(block.timestamp < a.allocationTime + CANCELATION_PERIOD, 'Cancellation period expired');
        a.state = AllocationState.Canceled;
        availableAmount += a.amount;
        _allocationTypes[uint256(a.allocationType)].availableAmount += a.amount;
        emit CancelAllocation(recipient_);
    }

    


    
    function claimTokens(address recipient_) public {
        Allocation storage a = _allocations[recipient_];
        require(AllocationState.Allocated == a.state, 'There is no allocation for the recipient');
        require(a.amountClaimed < a.amount, 'Allocations have already been transferred');
        AllocationStructure storage at = _allocationTypes[uint256(a.allocationType)];

        uint256 newPercentage = 0;

        if (a.allocationType == AllocationType.Ecosystem) {
            uint256 october1_2024 = 1727730000; 
            if (block.timestamp >= october1_2024) {
                uint256 periodsAfterOctober = (block.timestamp - october1_2024) / (10 * MONTH);
                newPercentage = 25 * (periodsAfterOctober + 1);
                if (newPercentage > 100) {
                    newPercentage = 100;
                }
            }
        } else if (a.allocationType == AllocationType.Marketing) {
        uint256 september23_2024 = 1727049600; 
        if (block.timestamp >= september23_2024) {
            uint256 quartersAfterSeptember = (block.timestamp - september23_2024) / (3 * MONTH);
            newPercentage = 10 + (30 * quartersAfterSeptember);
            if (newPercentage > 100) {
                newPercentage = 100;
            }
        }
    } else if (a.allocationType == AllocationType.Public) {
            uint256 september23_2024 = 1727049600; 
            if (block.timestamp >= september23_2024) {
                newPercentage = 100;
            }
    }  else {

        

        
            if (block.timestamp > a.allocationTime + at.lockupPeriod) {
                if (block.timestamp > a.allocationTime + at.lockupPeriod + at.vesting) {
                    newPercentage = 100;
                } else {

                    uint256 timeSinceLockupEnd = block.timestamp - (a.allocationTime + at.lockupPeriod);
                    uint256 monthsSinceLockupEnd = timeSinceLockupEnd / MONTH; 
                    newPercentage = 10 + (10 * monthsSinceLockupEnd);
                    if (newPercentage > 100) {
                        newPercentage = 100;
                   }
                            


                }
            }
        }

        uint256 newAmountClaimed = a.amount;
        if (newPercentage < 100) {
            newAmountClaimed = a.amount * newPercentage / 100;
        }
        require(newAmountClaimed > a.amountClaimed, 'Tokens for this period are already transferred');
        uint256 tokensToTransfer = newAmountClaimed - a.amountClaimed;
        require(token.transfer(recipient_, tokensToTransfer), 'Cannot transfer tokens');
        grandTotalClaimed += tokensToTransfer;
        a.amountClaimed = newAmountClaimed;
        emit TokenClaimed(recipient_, a.allocationType, tokensToTransfer);
    }




    function canClaimTokens(address recipient_) public view returns (bool) {
        Allocation storage a = _allocations[recipient_];
        if (a.state != AllocationState.Allocated) {
            return false;
        }

        uint256 newPercentage = 0;

        if (a.allocationType == AllocationType.Ecosystem) {
            uint256 october1_2024 = 1727730000;
            if (block.timestamp >= october1_2024) {
                uint256 periodsAfterOctober = (block.timestamp - october1_2024) / (10 * MONTH);
                newPercentage = 25 * (periodsAfterOctober + 1);
                if (newPercentage > 100) {
                    newPercentage = 100;
                }
            }
        } else if (a.allocationType == AllocationType.Marketing || a.allocationType == AllocationType.Public) {
            uint256 september23_2024 = 1727049600;
            if (block.timestamp >= september23_2024) {
                uint256 quartersAfterSeptember = (block.timestamp - september23_2024) / (3 * MONTH);
                newPercentage = 10 + (30 * quartersAfterSeptember);
                if (newPercentage > 100) {
                    newPercentage = 100;
                }
            }
        } else {
            AllocationStructure storage at = _allocationTypes[uint256(a.allocationType)];
            if (block.timestamp > a.allocationTime + at.lockupPeriod) {
                if (block.timestamp > a.allocationTime + at.lockupPeriod + at.vesting) {
                    newPercentage = 100;
                } else {
     
                    uint256 timeSinceLockupEnd = block.timestamp - (a.allocationTime + at.lockupPeriod);
                    uint256 monthsSinceLockupEnd = timeSinceLockupEnd / MONTH; 
                    newPercentage = 10 + (10 * monthsSinceLockupEnd);
                    if (newPercentage > 100) {
                        newPercentage = 100;
                    }
                }
            }
        }

        uint256 newAmountClaimed = a.amount * newPercentage / 100;
        return newAmountClaimed > a.amountClaimed;
    }


    function refundTokens(address recipientAddress_, address erc20Address_) external {

        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), 'Must have admin role to refund');
        require(erc20Address_ != address(token), 'Cannot refund tokens');
        ERC20 erc20 = ERC20(erc20Address_);
        uint256 balance = erc20.balanceOf(address(this));
        require(erc20.transfer(recipientAddress_, balance), 'Cannot transfer tokens');
    }


    function refund(address payable recipientAddress_) external payable {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), 'Must have admin role to refund');
        recipientAddress_.transfer(address(this).balance);
    }



    
    function allocatedAddresses() view external returns(address[] memory) {

        return _allocatedAddresses;
    }


    function allocationTypes() view external returns(AllocationStructure[SIZE_OF_ALLOCATIONS] memory) {

        return _allocationTypes;
    }


    function allocation(address address_)
        view
        external
        returns(AllocationType allocationType,
                uint256 allocationTime,
                uint256 amount,
                uint256 amountClaimed,
                AllocationState state) {

        allocationType = _allocations[address_].allocationType;
        allocationTime = _allocations[address_].allocationTime;
        amount = _allocations[address_].amount;
        amountClaimed = _allocations[address_].amountClaimed;
        state = _allocations[address_].state;
    }



    function _initAllocationTypes() private {


        _allocationTypes[uint256(AllocationType.Ecosystem)] = AllocationStructure(
            0,
            30 * MONTH,
            570000000 * DECIMAL_FACTOR,
            570000000 * DECIMAL_FACTOR
        ); 

        _allocationTypes[uint256(AllocationType.Advisors)] = AllocationStructure(
            1 * YEAR,
            10 * MONTH,
            30000000 * DECIMAL_FACTOR,
            30000000 * DECIMAL_FACTOR
        ); 

        _allocationTypes[uint256(AllocationType.Partners)] = AllocationStructure(
            1 * YEAR,
            10 * MONTH,
            50000000 * DECIMAL_FACTOR,
            50000000 * DECIMAL_FACTOR
        ); 



        _allocationTypes[uint256(AllocationType.Marketing)] = AllocationStructure(
            0,
            3 * MONTH,
            100000000 * DECIMAL_FACTOR,
            100000000 * DECIMAL_FACTOR
        );

        _allocationTypes[uint256(AllocationType.Presale)] = AllocationStructure(
            1 * YEAR,
            10 * MONTH,
            60000000 * DECIMAL_FACTOR,
            60000000 * DECIMAL_FACTOR
        ); 
        
        _allocationTypes[uint256(AllocationType.Private1)] = AllocationStructure(
            1 * YEAR,
            10 * MONTH,
            80000000 * DECIMAL_FACTOR,
            80000000 * DECIMAL_FACTOR
        );

        _allocationTypes[uint256(AllocationType.Private2)] = AllocationStructure(
            1 * YEAR,
            10 * MONTH,
            100000000 * DECIMAL_FACTOR,
            100000000 * DECIMAL_FACTOR
        ); 


             _allocationTypes[uint256(AllocationType.Public)] = AllocationStructure(
            0,
            0,
            10000000 * DECIMAL_FACTOR,
            10000000 * DECIMAL_FACTOR
        );
    }

    function _checkAllocations() view private {

        uint256 sum = 0;
        for (uint256 i = 0; i < SIZE_OF_ALLOCATIONS; ++i) {
            sum += _allocationTypes[i].totalAmount;
        }
        require(SUPPLY == sum, 'Invalid allocation types');

        
    }



    function _checkRole(address sender_, AllocationType allocationType_) view private {

        if (AllocationType.Ecosystem == allocationType_ || AllocationType.Marketing == allocationType_ || AllocationType.Advisors == allocationType_ || AllocationType.Partners == allocationType_) {
            require(hasRole(DISTRIBUTOR_ROLE, sender_), 'Must have role');
        } else if (AllocationType.Private1 == allocationType_
                        || AllocationType.Private2 == allocationType_
                        || AllocationType.Public == allocationType_
                        || AllocationType.Presale == allocationType_) {
            require(hasRole(SALE_ROLE, sender_), 'Must have role');
        } else {
            require(false, 'Unsupported allocation type');
        }
    }

    function getAvailableTokensForCategory(AllocationType allocationType_) public view returns (uint256) {
    return _allocationTypes[uint256(allocationType_)].availableAmount;
}
    



}