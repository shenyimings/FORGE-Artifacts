// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../vesting/Interfaces/IVestingFlex.sol";

contract TokenCustodian is AccessControlEnumerableUpgradeable {
    using SafeERC20 for IERC20;

    event Retrieved(Branch indexed branch, address indexed sender, address indexed beneficiary, uint256 amount);
    event BeneficiaryConfigured(Branch indexed branch, address indexed beneficiary, uint256 limit, bool active);

    bytes32 public constant STRATEGIC_SALE_ROLE   = keccak256("STRATEGIC_SALE");
    bytes32 public constant WORKING_GROUPS_ROLE   = keccak256("WORKING_GROUPS");
    bytes32 public constant ECOSYSTEM_GRANTS_ROLE = keccak256("ECOSYSTEM_GRANTS");    

    IERC20 public immutable TOKEN;
    IVestingFlex public immutable vest;

    uint256 public constant NUMBER_OF_BRANCHES = 3;

    string public constant BRANCHES = 
        "0: STRATEGIC_SALE \n 1: WORKING_GROUPS \n 2: ECOSYSTEM_GRANTS";

    enum Branch {
        STRATEGIC_SALE,
        WORKING_GROUPS,
        ECOSYSTEM_GRANTS
    }

    struct BranchProps {
        Branch index;
        string name;
        uint256 initialTotalAllocation;
        bytes32 role;
        uint256 balance;
        mapping(address => Beneficiary) beneficiary;
    }

    struct Beneficiary {
        uint120 maxAmount;
        uint120 claimedAmount;
        bool isRegistered;
    }

    mapping(Branch => BranchProps) public branchByIndex;

    constructor(IVestingFlex vestingContract) {
        _disableInitializers();
        vest = vestingContract;
        TOKEN = IERC20(vestingContract.token());
    }

    function initialize(
        address admin,
        string[3] calldata branches
    ) external initializer {
        __AccessControlEnumerable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        for(uint256 i = 0; i < NUMBER_OF_BRANCHES; i++) {
            BranchProps storage branch = branchByIndex[Branch(i)];
            IVestingFlex.Vesting memory vesting = vest.getVesting(address(this), i);

            require(vesting.vestedTotal != 0, "no vesting in place");

            branch.index = Branch(i);
            branch.name = branches[i];
            branch.initialTotalAllocation = vesting.vestedTotal;
            branch.role = keccak256(bytes(branches[i]));

            require(
                branch.role == STRATEGIC_SALE_ROLE || 
                branch.role == ECOSYSTEM_GRANTS_ROLE || 
                branch.role == WORKING_GROUPS_ROLE,
                "role doesnt match constant role"
            );
        }
    }

    function retrieve(
        Branch branch_,
        address beneficiary_,
        uint256 amount,
        bool claimPending
    ) external onlyRole(branchByIndex[branch_].role) {
        BranchProps storage branch = branchByIndex[branch_];

        _enforceBeneficiaryLimit(branch.beneficiary[beneficiary_], amount);

        if(claimPending) {
            uint256 claimed  = vest.retrieve(uint256(branch_));
            branch.balance += claimed;
        }

        branch.balance -= amount;
        _processPayment(beneficiary_, amount);
        emit Retrieved(branch_, msg.sender, beneficiary_, amount);
    }

    function configureBeneficiaryInBranch(
        Branch branch_,
        address beneficiary_,
        uint256 maxAmount,
        bool isRegistered
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Beneficiary storage beneficiary = branchByIndex[branch_].beneficiary[beneficiary_];

        beneficiary.maxAmount = maxAmount > uint256(beneficiary.claimedAmount)
            ? uint120(maxAmount)
            : uint120(beneficiary.claimedAmount);

        beneficiary.isRegistered = isRegistered;

        emit BeneficiaryConfigured(branch_, beneficiary_, maxAmount, isRegistered);
    }

    /// VIEW
    function totalAllocation(Branch branch) public view returns(uint256) {
        return branchByIndex[branch].initialTotalAllocation;
    }

    function totalReserves(Branch branch) public view returns(uint256) {
        return totalAllocation(branch) - totalUsedInBranch(branch);
    }

    function totalUsedInBranch(Branch branch) public view returns(uint256) {
        return vest.getClaimed(address(this), uint256(branch)) - branchByIndex[branch].balance;
    }

    function availableInBranch(Branch branch) public view returns(uint256) {
        return availableInBranchAtTimestamp(branch, block.timestamp);
    }

    function availableInBranchAtTimestamp(Branch branch, uint256 when) public view returns(uint256) {
        return branchByIndex[branch].balance + vest.getClaimableAtTimestamp(address(this), uint256(branch), when);
    }

    /// INTERNAL
    function _processPayment(address to, uint256 amount) internal {
        TOKEN.safeTransfer(to, amount);
    }

    function _enforceBeneficiaryLimit(Beneficiary storage beneficiary, uint256 amount) internal {
        uint256 claimedAfter = beneficiary.claimedAmount + amount;
        require(beneficiary.isRegistered, "unkown beneficiary");
        require(claimedAfter <= beneficiary.maxAmount, "no more limit");
        beneficiary.claimedAmount = uint120(claimedAfter);
    }
}