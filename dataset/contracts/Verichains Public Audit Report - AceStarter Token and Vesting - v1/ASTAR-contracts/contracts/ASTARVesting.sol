// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ASTARVesting is AccessControl {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    IERC20 public token;
    string public name;
    uint public tge;

    uint public reserveAmount;
    uint public lastBalanceAfterRelease;
    uint private totalToken;

    uint private beneficiariesAmount;
    mapping(address => uint) private beneficiaries;
    mapping(address => uint) private tgeReleases;
    mapping(address => uint) private released;
    mapping(address => uint) private cliffDurations;
    mapping(address => uint) private vestingDurations;
    mapping(address => bool) private blockBeneficiaries;

    event Released(address beneficiary, uint amount);
    event Blocked(address beneficiary, string reason);
    event Unblocked(address beneficiary);

    constructor(string memory _name, uint _reserveAmount) {
        name = _name;
        reserveAmount = _reserveAmount;
        _setRoleAdmin(DEPLOYER_ROLE, DEPLOYER_ROLE);
        _setupRole(DEPLOYER_ROLE, msg.sender);
    }

    function setToken(address erc20) public onlyRole(DEPLOYER_ROLE) {
        require(address(token) == address(0), "The token is setted");
        token = IERC20(erc20);
    }

    function startTGE() public onlyRole(DEPLOYER_ROLE) {
        require(tge == 0, "TGE started before");
        tge = block.timestamp;
    }

    function addBeneficiary(address beneficiary, uint total, uint tgeRelease, uint cliffDuration, uint vestingDuration) public onlyRole(DEPLOYER_ROLE) {
        require(beneficiary != address(0) && beneficiaries[beneficiary] == 0, "The beneficiary is existed");
        require(reserveAmount >= total + beneficiariesAmount, "The balance is not enough");
        require(tgeRelease <= total, "The TGE release is invalid");

        tgeReleases[beneficiary] = tgeRelease;
        cliffDurations[beneficiary] = cliffDuration;
        vestingDurations[beneficiary] = vestingDuration;
        blockBeneficiaries[beneficiary] = false;

        beneficiaries[beneficiary] = total;
        beneficiariesAmount += total;
    }

    function getAllocation(address beneficiary) public view returns (uint) {
        require(beneficiaries[beneficiary] > 0, "The beneficiary address is invalid");
        return beneficiaries[beneficiary];
    }

    function getTGERelease(address beneficiary) public view returns (uint) {
        require(beneficiaries[beneficiary] > 0, "The beneficiary address is invalid");
        return tgeReleases[beneficiary];
    }

    function getReleased(address beneficiary) public view returns (uint) {
        require(beneficiaries[beneficiary] > 0, "The beneficiary address is invalid");
        return released[beneficiary];
    }

    function getCliffDuration(address beneficiary) public view returns (uint) {
        require(beneficiaries[beneficiary] > 0, "The beneficiary address is invalid");
        return cliffDurations[beneficiary];
    }

    function getCliff(address beneficiary) public view returns (uint) {
        require(beneficiaries[beneficiary] > 0, "The beneficiary address is invalid");
        require(tge > 0, "TGE is not config");
        return tge + cliffDurations[beneficiary];
    }

    function getVestingDuration(address beneficiary) public view returns (uint) {
        require(beneficiaries[beneficiary] > 0, "The beneficiary address is invalid");
        return vestingDurations[beneficiary];
    }

    function blockBeneficiary(address beneficiary, string memory reason) public onlyRole(DEPLOYER_ROLE) {
        require(beneficiaries[beneficiary] > 0, "The beneficiary address is invalid");
        blockBeneficiaries[beneficiary] = true;
        emit Blocked(beneficiary, reason);
    }

    function unBlockBeneficiary(address beneficiary) public onlyRole(DEPLOYER_ROLE) {
        require(beneficiaries[beneficiary] > 0, "The beneficiary address is invalid");
        blockBeneficiaries[beneficiary] = false;
        emit Unblocked(beneficiary);
    }

    function release(address beneficiary) public {
        require(blockBeneficiaries[beneficiary] == false, "The beneficiary is not exists or blocked");

        uint vestableAmount = vestable(beneficiary);

        require(vestableAmount > 0, "The is nothing to vest");

        totalToken = getTotalToken();
        released[beneficiary] += vestableAmount;
        lastBalanceAfterRelease = token.balanceOf(address(this)) - vestableAmount;

        bool transfer = token.transfer(beneficiary, vestableAmount);
        require(transfer, "Cannot transfer");
        emit Released(beneficiary, vestableAmount);
    }

    function vestable(address beneficiary) public view returns (uint) {
        require(beneficiaries[beneficiary] > 0, "The beneficiary address is invalid");
        require(tge > 0, "TGE is not config");
        uint amount = 0;

        if (block.timestamp < tge + cliffDurations[beneficiary]) {
            amount = tgeReleases[beneficiary];
        } else if (block.timestamp >= (tge + cliffDurations[beneficiary] + vestingDurations[beneficiary])) {
            amount = beneficiaries[beneficiary];
        } else {
            uint vestingAmount = beneficiaries[beneficiary] - tgeReleases[beneficiary];
            uint currentVestingTime = block.timestamp - (tge + cliffDurations[beneficiary]);

            amount = (((vestingAmount * currentVestingTime) / vestingDurations[beneficiary])) + tgeReleases[beneficiary];
        }
        uint _vestable = (amount * getTotalToken() / reserveAmount) - released[beneficiary];
        return _vestable;
    }

    function getTotalToken() public view returns (uint){
        uint _curBalance = token.balanceOf(address(this));
        if (lastBalanceAfterRelease > 0)
        {
            if (_curBalance > lastBalanceAfterRelease) {
                return totalToken + _curBalance - lastBalanceAfterRelease;
            }
            return totalToken;
        }
        return _curBalance;
    }
    /**
     * Emergency functions
     */
    function withdrawERC20(address erc20, uint amount) public onlyRole(DEPLOYER_ROLE) {
        require(IERC20(erc20).balanceOf(address(this)) >= amount, "Not enough");
        bool transfer = IERC20(erc20).transfer(msg.sender, amount);
        require(transfer, "Cannot transfer");
    }
}
