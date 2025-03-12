// contracts/ETNGovernance.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./ETNGovernanceInterface.sol";

contract ETNGovernance is ETNGovernanceInterface, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    
    struct Supporter {
        address validatorAddress;
        uint256 stake;
    }

    struct Validator {
        address addr;
        uint256 stake;
        address[] supporters;
        uint256 votes;
        uint8 score;
        bool isInitial;
    }

    uint8 private maxValidators;
    uint256 private minStakeAmount;

    Validator[] private validators;
    mapping(address => uint) private validatorsMap;
    mapping(address => Supporter[]) private supportersMap;
    address[] private epochValidators;

    modifier isValidator() {
        require(validatorsMap[msg.sender] > 0, "address is not a validator.");
        _;
    }

    modifier isNotValidator() {
        require(validatorsMap[msg.sender] == 0, "address is a validator.");
        _;
    }

    modifier isValidatorInEpoch() {
        require(validatorsMap[msg.sender] > 0, "address is not a validator.");
        bool found = false;
        for(uint i = 0; i < epochValidators.length; i++) {
            if(epochValidators[i] == msg.sender) {
                found = true;
                break;
            }
        }
        require(found, "validator is not active in epoch");
        _;
    }

    modifier isSupporter() {
        require(supportersMap[msg.sender].length > 0, "address is not a supporter.");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address[] memory initialValidators) public initializer {
        require(initialValidators.length > 0, "no initial validator accounts");

        __Ownable_init();
        __UUPSUpgradeable_init();

        for (uint i = 0; i < initialValidators.length; i++) {
            _addValidator(initialValidators[i], minStakeAmount, true);
            epochValidators.push(initialValidators[i]);
        }
        maxValidators = 24;
        minStakeAmount = 5000000 ether;
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function candidateRegistration() public payable isNotValidator {
        require(msg.value >= minStakeAmount, "registration amount too little");
        require((msg.value % 1 ether) == 0, "amount must be multiple of 1ETN");
        _addValidator(msg.sender, msg.value, false);
    }

    function withdrawRegistration() public isValidator {
        require(validatorsMap[msg.sender] > 0, "address is not a candidate");
        _removeValidator(msg.sender);
    }

    function candidateSupport(address validatorAddress) public payable {
        require(validatorsMap[validatorAddress] > 0, "validator address not found");
        require(msg.value > 0, "support ammount can't be zero");
        require((msg.value % 10 ether) == 0, "amount must be multiple of 10ETN");
        _addCandidateSupport(validatorAddress, msg.sender, msg.value);
    }

    function withdrawSupport(address validatorAddress) public isSupporter {
        require(validatorsMap[validatorAddress] > 0, "validator address not found");
        require(supportersMap[msg.sender].length > 0, "supporter not found");
        _removeCandidateSupport(validatorAddress, msg.sender);
    }

    function newEpoch() override public {
        //require((blockNumber+1) % 17280 == 0, "not ready for new epoch");

        Validator[] memory v = validators;
        for(uint i = 0; i < v.length; i++) {
            v[i].votes = v[i].votes * (v[i].score / 100);
        }
        _sortValidators(v, int(0), int(v.length-1));
        
        delete epochValidators;

        for(uint i = 0; i < maxValidators && i < v.length; i++) {
            epochValidators.push(v[v.length-1-i].addr);
        }
    }

    function slashValidator(address validatorAddress) override external {
    }

    /*------------------------ views ------------------------*/

    function getValidators() override public view returns (address[] memory) {
        return epochValidators;
    }

    function getValidatorVotes(address validatorAddress) public view returns (uint) {
        uint index = validatorsMap[validatorAddress];
        if(index == 0) return 0;
        return validators[index-1].votes;
    }

    function getValidatorScore(address validatorAddress) public view returns (uint) {
        uint index = validatorsMap[validatorAddress];
        if(index == 0) return 0;
        return validators[index-1].score;
    }

    function getSupporterStakeAmount(address supporterAddress) public view returns (Supporter[] memory) {
        return supportersMap[supporterAddress];
    }

    /*------------------------ privates ------------------------*/

    function _sortValidators(Validator[] memory arr, int left, int right) private {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = arr[uint(left + (right - left) / 2)].votes;
        while (i <= j) {
            while (arr[uint(i)].votes < pivot) i++;
            while (pivot < arr[uint(j)].votes) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            _sortValidators(arr, left, j);
        if (i < right)
            _sortValidators(arr, i, right);
    }

    function _addValidator(address _addr, uint256 _value, bool _isInitial) private {
        uint256 stakeValue = 0;
        if(!_isInitial) {
            stakeValue = _value;
        }
        
        address[] memory emptyAddressList;
        validators.push(Validator({
            addr: _addr, 
            stake: stakeValue,
            supporters: emptyAddressList,
            votes: _value / (1 ether),
            score: 100,
            isInitial: _isInitial
        }));

        validatorsMap[_addr] = validators.length;
    }

    function _removeValidator(address _addr) private {
        uint index;
        address valAddress;
        uint refundAmount;
        for(uint i = 0; i < validators.length; i++) {
            if(_addr == validators[i].addr) {
                index = i;
                Validator memory val = validators[i];

                for(uint j = 0; j < val.supporters.length; j++) {
                    _removeCandidateSupport(_addr, val.supporters[j]);
                }

                valAddress = val.addr;
                refundAmount = val.stake;
                break;
            }
        }

        validators[index] = validators[validators.length - 1];
        validators.pop();
        delete validatorsMap[_addr];

        for(uint i = 0; i < validators.length; i++) {
            validatorsMap[validators[i].addr] = i + 1;
        }

        address payable valPayableAddress = payable(valAddress);
        valPayableAddress.transfer(refundAmount);
    }

    function _addCandidateSupport(address _validatorAddress, address _supporterAddress, uint256 _value) private {
        bool found = false;
        for(uint i = 0; i < supportersMap[_supporterAddress].length; i++) {
            if(supportersMap[_supporterAddress][i].validatorAddress == _validatorAddress) {
                found = true;
                supportersMap[_supporterAddress][i].stake += _value;
                break;
            }
        }

        if(!found) {
            supportersMap[_supporterAddress].push(Supporter(_validatorAddress, _value));
            uint valIndex = validatorsMap[_validatorAddress] - 1;
            validators[valIndex].supporters.push(_supporterAddress);
        }

        _computeValidatorVotes(_validatorAddress);
    }

    function _removeCandidateSupport(address _validatorAddress, address _supporterAddress) private {
        bool found = false;
        uint index;
        for(uint i = 0; i < supportersMap[_supporterAddress].length; i++) {
            if(supportersMap[_supporterAddress][i].validatorAddress == _validatorAddress) {
                found = true;
                index = i;
                break;
            }
        }

        require(found, "does not support this validator");

        uint refundAmount = supportersMap[_supporterAddress][index].stake;
        
        supportersMap[_supporterAddress][index] = supportersMap[_supporterAddress][supportersMap[_supporterAddress].length - 1];
        supportersMap[_supporterAddress].pop();


        uint valIndex = validatorsMap[_validatorAddress] - 1;
        Validator storage v = validators[valIndex];
        found = false;
        for(uint i = 0; i < v.supporters.length; i++) {
            if(v.supporters[i] == _supporterAddress) {
                found = true;
                index = i;
                break;
            }
        }

        assert(found == true);

        v.supporters[index] = v.supporters[v.supporters.length - 1];
        v.supporters.pop();

        _computeValidatorVotes(_validatorAddress);

        address payable supPayableAddress = payable(_supporterAddress);
        supPayableAddress.transfer(refundAmount);
    }

    function _findAddress(address[] memory _array, address _addr) private pure returns (bool) {
        for(uint i = 0; i < _array.length; i++) {
            if(_addr == _array[i]) return true;
        }
        return false;
    }

    function _computeValidatorVotes(address _validatorAddress) private {
        require(validatorsMap[_validatorAddress] > 0, "validator address not found");
        uint index = validatorsMap[_validatorAddress] - 1;

        uint votes;
        for(uint i = 0; i < validators[index].supporters.length; i++) {
            for(uint j = 0; j < supportersMap[validators[index].supporters[i]].length; j++) {
                Supporter memory s = supportersMap[validators[index].supporters[i]][j];
                if(s.validatorAddress == _validatorAddress) {
                    votes += s.stake / (10 ether);
                    break;
                }
            }
        }

        votes += validators[index].stake / (1 ether);

        validators[index].votes = votes;
    }
}