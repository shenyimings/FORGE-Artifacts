// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./Founder.sol";
import "./InvestorLogin.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PrivateRound is Initializable, UUPSUpgradeable, OwnableUpgradeable{

    // CUSTOM ERROR
    error roundIdNotLinkedToInvestor();
    error roundIdNotLinkedToFounder();
    error zeroAddress();
    error tokenAlreadyExist();
    error tokenNotSupported();

    // STATE VARIABLES
    address public contractOwner;
    // This state varibale holds the contract address necessary for the privateRound.
    address private InvestorLoginContract;
    address private FounderContract;
    // address public tokenContract;
    mapping(uint => address) public tokenContract;
    address private _grantedOwner;
    // holds the suitable tokens to be used for this contract. 
    bool private contractInitialized;
    // This is an incremental roundId setup for the contract.
    uint private roundIdContract;
    
    // EVENTS:
    event OwnershipGranted(address);
    event roundCreated(address indexed from, address indexed to, uint indexed roundId);
    event deposited(address indexed from, address indexed to, uint256 indexed amount);
    event initialPercentageWithdrawn(address indexed to, uint256 indexed amount);
    event milestoneValidation(uint indexed milestone, uint indexed round, bool indexed status);
    event withdrawByInvestor(address indexed to, uint indexed amount);
    event withdrawByFounder(address indexed to, uint indexed amount);
    event batchWithdraw(address indexed to, uint indexed amount);
    event withdrawTax(address indexed to, uint indexed amount);

    // MODIFIERS:
    /*
        * This dynamically changes everytime token address is submitted.
        * Either by Investor or Founder.
    */    

    modifier onlyAdmin(){
        require(msg.sender == contractOwner,"Sender is not the owner of this contract");
        _;
    }

    modifier isInitialized(){
        require(contractInitialized == true,"The contract is not yet initialized");
        _;
    }

    // ARRAY
    address[] private tokenContractAddress;
    
    // STRUCT
    struct MilestoneSetup {
        uint256 _num;
        uint256 _date;
        uint256 _percent;
    }

    // MAPPINGS:
    mapping(address => mapping(uint => MilestoneSetup[])) private _milestone; // sets investor address to mileStones created by the founder.
    mapping(uint => mapping(address => uint)) public initialPercentage;  // round id => investor => initialPercentage   
    mapping(uint => mapping(address => address)) public seperateContractLink;  // round id => founder => uinstance contract address.   
    mapping(uint => bool) private roundIdControll; 
    /**
    create mapping for isWhether founder address is for this roundId.
    create mapping for isWhether investor address is for this roundId.
    */
    mapping(address => mapping(uint => bool)) private isRoundIdForFounder;
    mapping(address => mapping(uint => bool)) private isRoundIdForInvestor;
    mapping(address => uint[]) private getRoundId;
    mapping(uint => mapping(address => uint)) public remainingTokensOfInvestor;  // round id => investor => tokens   
    mapping(uint => mapping(address => uint)) public totalTokensOfInvestor;    // round id => investor => tokens 
    mapping(uint => mapping(address => uint)) public initialTokensForFounder;  // round id => founder => tokens
    mapping(uint => mapping(address => bool)) private initialWithdrawalStatus;
    mapping(uint => address) private contractAddress;
    mapping(address => bool) private addressExist;
    mapping(address => uint) public taxedTokens;
    mapping(uint => uint) private withdrawalFee;
    mapping(uint => mapping(uint => uint)) private rejectedByInvestor;
    mapping(uint => bool) private projectCancel;
    mapping(uint => mapping(uint => address)) private requestForValidation;
    mapping(uint => mapping(uint => int)) private milestoneApprovalStatus; // 0 - means default null, 1 - means approves, -1 means rejected.
    mapping(uint => mapping(uint => bool)) private milestoneWithdrawalStatus;
    mapping(address => mapping(uint => uint)) private investorWithdrawnTokens;  // investor add => roundid => withdrawn token
    
    
    // After deploying the contract, deployer stricly needs to activate this function if initialize is not set.
    function initialize() external initializer{
      ///@dev as there is no constructor, we need to initialise the OwnableUpgradeable explicitly
       __Ownable_init();
       contractOwner = msg.sender;
       contractInitialized = true;
       roundIdContract = 0;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
    
    /**
        * Whitelist contract this is necessary for InvestorLogin:
        * @param _contractAddressInvestor This sets the investorLoginContract Address.
    */
    function whitelistInvestorLoginContract(address _contractAddressInvestor) external onlyAdmin{
        if(_contractAddressInvestor == address(0)){ revert zeroAddress();}
        InvestorLoginContract = _contractAddressInvestor;
    }
    /**
        * Whitelist contract this is necessary for Founder:
        * @param _contractAddressFounder This sets the FounderContract Address.
    */
    function whitelistFounderContract(address _contractAddressFounder) external onlyAdmin{
        if(_contractAddressFounder == address(0)){ revert zeroAddress();}
        FounderContract = _contractAddressFounder;
    }
  
    // Write Functions:
    /**
        * createPrivateRound
        * @param  _founder Enter the founder address, for who private round is created.
        * @param _initialPercentage Enter the initial percantange of amount needs to be unlocked after deposit.
        * @param _mile Set the number of milestone for the founder.
    */
    function createPrivateRound(address _founder, uint _initialPercentage, MilestoneSetup[] memory _mile) external isInitialized{
        InvestorLogin investor = InvestorLogin(InvestorLoginContract);
        require(investor.verifyInvestor(msg.sender), "The address is not registered in the 'InvestorLogin' contract");
        roundIdContract = roundIdContract + 1;
        isRoundIdForInvestor[msg.sender][roundIdContract] = true;
        for(uint i = 0; i < _mile.length; ++i){
            _milestone[msg.sender][roundIdContract].push(_mile[i]);
            milestoneApprovalStatus[roundIdContract][_mile[i]._num] = 0;
            milestoneWithdrawalStatus[roundIdContract][_mile[i]._num] = false;
        }
        initialPercentage[roundIdContract][msg.sender] = _initialPercentage;
        getRoundId[msg.sender].push(roundIdContract);
        getRoundId[_founder].push(roundIdContract);
        emit roundCreated(msg.sender, _founder, roundIdContract);
    }

    /**
        * whitelistToken.  
        * Whitelist the token address, so that only tokensfrom the whitelist works.
        * @param _tokenContract Enter the token contract address to be logged to the smart contract.
    */
    function whitelistToken(address _tokenContract) external onlyAdmin{
        if(_tokenContract == address(0)){ revert zeroAddress();}
        if(addressExist[_tokenContract] == true){ revert tokenAlreadyExist();}
        addressExist[_tokenContract] = true;
        tokenContractAddress.push(_tokenContract);
    }

    /**
        * depositTokens
        * @param _tokenContract Enter the token contract address.
        * @param _founder Enter the founder address.
        * @param _tokens Enter how many tokens needs to be deposited for the founder.
        * @param _roundId Enter the roundId generated while creating the privateRound.
    */
    function depositTokens(address _tokenContract, address _founder, uint _tokens, uint _roundId) external isInitialized{
        require(_tokenContract != address(0), "The smart contract address is invalid");
        InvestorLogin investor = InvestorLogin(InvestorLoginContract);
        require(investor.verifyInvestor(msg.sender), "The address is not registered in the 'InvestorLogin' contract");
        if(isRoundIdForInvestor[msg.sender][_roundId] != true){ revert roundIdNotLinkedToInvestor();}
        if(addressExist[_tokenContract] != true){ revert tokenNotSupported();}
        isRoundIdForFounder[_founder][_roundId] = true;
        tokenContract[_roundId] = _tokenContract;
        FundLock fl = new FundLock(msg.sender, _roundId, _tokens, address(this));
        seperateContractLink[_roundId][_founder] = address(fl);
        contractAddress[_roundId] = address(fl);
        remainingTokensOfInvestor[_roundId][msg.sender] = _tokens;
        totalTokensOfInvestor[_roundId][msg.sender] = _tokens;
        uint tax = _tokens * initialPercentage[_roundId][msg.sender] / 100;
        initialTokensForFounder[_roundId][_founder] += tax;
        remainingTokensOfInvestor[_roundId][msg.sender] -= initialTokensForFounder[_roundId][_founder];
        require(ERC20(_tokenContract).transferFrom(msg.sender, seperateContractLink[_roundId][_founder], _tokens), "transaction failed or reverted");
        emit deposited(msg.sender, _founder, _tokens);
    }

    /**
        * withdrawInitialPercentage
        * @param _tokenContract Enter the token contract address.
        * @param _roundId Enter the roundId generated while creating the privateRound.
    */
    function withdrawInitialPercentage(address _tokenContract, uint _roundId) external isInitialized{ // 2% tax should be levied on the each transaction
        if(addressExist[_tokenContract] != true){ revert tokenNotSupported();}
        Founder founder = Founder(FounderContract);
        require(founder.verifyFounder(msg.sender), "The address is not registered in the 'Founder' contract");
        if(initialWithdrawalStatus[_roundId][msg.sender]){
            revert("Initial withdrawal is already done");
        }
        if(isRoundIdForFounder[msg.sender][_roundId] != true){ revert roundIdNotLinkedToFounder();}
        FundLock fl = FundLock(seperateContractLink[_roundId][msg.sender]);
        uint tax = 2 * (initialTokensForFounder[_roundId][msg.sender] / 100);
        taxedTokens[_tokenContract] += tax;
        initialTokensForFounder[_roundId][msg.sender] -= tax;
        withdrawalFee[_roundId] += tax;
        initialWithdrawalStatus[_roundId][msg.sender] = true;
        require(ERC20(_tokenContract).transferFrom(address(fl), msg.sender, initialTokensForFounder[_roundId][msg.sender]), "transaction failed or reverted");
        emit initialPercentageWithdrawn(msg.sender, initialTokensForFounder[_roundId][msg.sender]);
    }

    /**
        * milestoneValidationRequest
        * @param _milestoneId Enter the milestoneID, for validation set during the privateRound creation.
        * @param _roundId Enter the roundId generated while creating the privateRound.
    */
    function milestoneValidationRequest(uint _milestoneId, uint _roundId) external isInitialized{
        Founder founder = Founder(FounderContract);
        require(founder.verifyFounder(msg.sender), "The address is not registered in the 'Founder' contract");
        if(isRoundIdForFounder[msg.sender][_roundId] != true){ revert roundIdNotLinkedToFounder();}
        requestForValidation[_roundId][_milestoneId] = msg.sender;
    }

    /**
        * validateMilestone
        * @param _milestoneId Enter the milestoneID, for validation set during the privateRound creation.
        * @param _roundId Enter the roundId generated while creating the privateRound.
        * @param _status Enter "true" for approved, or "false" for rejected.
    */
    function validateMilestone(uint _milestoneId, uint _roundId, bool _status) external isInitialized{
        InvestorLogin investor = InvestorLogin(InvestorLoginContract);
        require(investor.verifyInvestor(msg.sender), "The address is not registered in the 'InvestorLogin' contract");
        if(isRoundIdForInvestor[msg.sender][_roundId] != true){ revert roundIdNotLinkedToInvestor();}
        if(milestoneApprovalStatus[_roundId][_milestoneId] == 1){
            revert("The milestone is already approved");
        }
        if(_status){
            milestoneApprovalStatus[_roundId][_milestoneId] = 1;
        }else{
            rejectedByInvestor[_roundId][_milestoneId] += 1;
            milestoneApprovalStatus[_roundId][_milestoneId] = -1;
        }
        if(rejectedByInvestor[_roundId][_milestoneId] >= 3){
            projectCancel[_roundId] = true;
        }
        emit milestoneValidation(_milestoneId, _roundId, _status);
    }

    /**
        * withdrawIndividualMilestoneByFounder
        * @param _investor Enter the investor address.
        * @param _roundId Enter the roundId generated while creating the privateRound.
        * @param _milestoneId Enter the milestoneID, for validation set during the privateRound creation.
        * @param _percentage Enter the percentage set during the privateRound creation.
        * @param _tokenContract Enter the token contract address.
    */
    function withdrawIndividualMilestoneByFounder(address _investor, uint _roundId, uint _milestoneId, uint _percentage, address _tokenContract) external isInitialized{
        if(addressExist[_tokenContract] != true){ revert tokenNotSupported();}
        Founder founder = Founder(FounderContract);
        require(founder.verifyFounder(msg.sender), "The address is not registered in the 'Founder' contract");
        if(isRoundIdForFounder[msg.sender][_roundId] != true){ revert roundIdNotLinkedToFounder();}
        uint unlockedAmount = 0;
        if(milestoneApprovalStatus[_roundId][_milestoneId] == 1 && !milestoneWithdrawalStatus[_roundId][_milestoneId]){
            unlockedAmount = (totalTokensOfInvestor[_roundId][_investor] * _percentage)/ 100;
            milestoneWithdrawalStatus[_roundId][_milestoneId] = true;
            remainingTokensOfInvestor[_roundId][_investor] -= unlockedAmount;
        }
        if(unlockedAmount > 0){
            uint tax = (2 * unlockedAmount) / 100;
            taxedTokens[_tokenContract] += tax;
            unlockedAmount -= tax;
            withdrawalFee[_roundId] += tax;
            FundLock fl = FundLock(seperateContractLink[_roundId][msg.sender]);
            require(ERC20(_tokenContract).transferFrom(address(fl), msg.sender, unlockedAmount), "transaction failed or reverted");
            emit withdrawByFounder(msg.sender, unlockedAmount);
        }else{
            revert("No unlocked tokens to withdraw");
        } 
    }

    /**
        *  withdrawIndividualMilestoneByInvestor
        * @param _roundId Enter the roundId generated while creating the privateRound.
        * @param _founder Enter the founder address.
        * @param _milestoneId Enter the milestoneID, for validation set during the privateRound creation.
        * @param _percentage Enter the percentage set during the privateRound creation.
        * @param _tokenContract Enter the token contract address.
    */
    function withdrawIndividualMilestoneByInvestor(uint _roundId, address _founder, uint _milestoneId, uint _percentage, address _tokenContract) external isInitialized{
        if(addressExist[_tokenContract] != true){ revert tokenNotSupported();}
        InvestorLogin investor = InvestorLogin(InvestorLoginContract);
        require(investor.verifyInvestor(msg.sender), "The address is not registered in the 'InvestorLogin' contract");
        if(isRoundIdForInvestor[msg.sender][_roundId] != true){ revert roundIdNotLinkedToInvestor();}
        uint count = 0;
        for(uint i = 0; i < _milestone[msg.sender][_roundId].length; i++){
            if(block.timestamp > _milestone[msg.sender][_roundId][i]._date && requestForValidation[_roundId][_milestone[msg.sender][_roundId][i]._num] != _founder){
                count += 1;
            }
        }
        if(projectCancel[_roundId] || count >= 2){
            uint lockedAmount = 0;
            if(milestoneApprovalStatus[_roundId][_milestoneId] != 1){
                lockedAmount += (totalTokensOfInvestor[_roundId][msg.sender] * _percentage) / 100;
                remainingTokensOfInvestor[_roundId][msg.sender] -= lockedAmount;
            }
            if(lockedAmount > 0){
                FundLock fl = FundLock(seperateContractLink[_roundId][_founder]);
                uint tax = (2 * lockedAmount)/ 100;
                taxedTokens[_tokenContract] += tax;
                withdrawalFee[_roundId] += tax;
                lockedAmount -= tax;
                investorWithdrawnTokens[msg.sender][_roundId] = lockedAmount;
                require(ERC20(_tokenContract).transferFrom(address(fl), msg.sender, lockedAmount), "transaction failed or reverted"); 
                emit withdrawByInvestor(msg.sender, lockedAmount);
            }
        }
    }

    /**
        *  batchWithdrawByInvestors
        * @param _roundId Enter the roundId generated while creating the privateRound.
        * @param _founder Enter the founder address.
        * @param _tokenContract Enter the token contract address.
    */
    function batchWithdrawByInvestors(uint _roundId, address _founder, address _tokenContract) external isInitialized{
        if(addressExist[_tokenContract] != true){ revert tokenNotSupported();}
        InvestorLogin investor = InvestorLogin(InvestorLoginContract);
        require(investor.verifyInvestor(msg.sender), "The address is not registered in the 'InvestorLogin' contract");
        if(isRoundIdForInvestor[msg.sender][_roundId] != true){ revert roundIdNotLinkedToInvestor();}
        uint count = 0;
        for(uint i = 0; i < _milestone[msg.sender][_roundId].length; i++){
            if(block.timestamp > _milestone[msg.sender][_roundId][i]._date && requestForValidation[_roundId][_milestone[msg.sender][_roundId][i]._num] != _founder){
                count += 1;
            }
        }
        uint lockedAmount = 0;
        if(projectCancel[_roundId] || count >= 2){
            for(uint i = 0; i < _milestone[msg.sender][_roundId].length; i++){
                if(milestoneApprovalStatus[_roundId][_milestone[msg.sender][_roundId][i]._num] != 1){
                    lockedAmount += (totalTokensOfInvestor[_roundId][msg.sender] * _milestone[msg.sender][_roundId][i]._percent) / 100;
                    remainingTokensOfInvestor[_roundId][msg.sender] -= lockedAmount;
                }
            }
            if(lockedAmount > 0){
                FundLock fl = FundLock(seperateContractLink[_roundId][_founder]);
                uint tax = (2 * lockedAmount)/ 100;
                taxedTokens[_tokenContract] += tax;
                withdrawalFee[_roundId] += tax;
                lockedAmount -= tax;
                investorWithdrawnTokens[msg.sender][_roundId] = lockedAmount;
                require(ERC20(_tokenContract).transferFrom(address(fl), msg.sender, lockedAmount), "transaction failed or reverted"); 
                emit batchWithdraw(msg.sender, lockedAmount);
            }
        }
    }

    /**
        * grantOwnership.
        * Two factor ownership granting process.
        * @param newOwner , sets netOwner as admin for the contract, buts ownership needs to be claimed.
    */
    function grantOwnership(address newOwner) public virtual onlyAdmin {
        emit OwnershipGranted(newOwner);
        _grantedOwner = newOwner;
    }

    /**
        * claimOwnership.
        * Two factor ownership granting process.
    */
    function claimOwnership() public virtual {
        require(_grantedOwner == _msgSender(), "Ownable: caller is not the granted owner");
        emit OwnershipTransferred(contractOwner, _grantedOwner);
        contractOwner = _grantedOwner;
        _grantedOwner = address(0);
    }

    /**
        *  withdrawTaxTokens
        * @param _tokenContract Enter the token contract address.
        * @param _roundId Enter the roundId generated while creating the privateRound.
        * @param _founder Enter the founder address.
    */
    function withdrawTaxTokens(address _tokenContract, uint _roundId, address _founder) external onlyAdmin { // All the taxed tokens are there in the contract itself. no instance is created
        if(addressExist[_tokenContract] != true){ revert tokenNotSupported();}
        FundLock fl = FundLock(seperateContractLink[_roundId][_founder]);
        uint tax = taxedTokens[_tokenContract];
        taxedTokens[_tokenContract] = 0;
        require(ERC20(_tokenContract).transferFrom(address(fl), msg.sender, tax), "execution failed or reverted");
        emit withdrawTax(msg.sender, tax);
    }   

    /*
        * READ FUNCTIONS:
    */

    function GetRoundIdByInvestor(address _investor, uint256 _array) public view returns(uint256){
        return getRoundId[_investor][_array];
    }

    function GetRoundIdByFounder(address _founder, uint256 _array) public view returns(uint256){
        return getRoundId[_founder][_array];
    }

    function milestoneStatusChk(uint roundId, uint milestoneId) external view returns(int){
        return milestoneApprovalStatus[roundId][milestoneId];
    }

    function getContractAddress(uint _roundId) external view returns(address smartContractAddress){
        return contractAddress[_roundId];
    }

    function projectStatus(uint _roundId) external view returns(bool projectLiveOrNot){
        return projectCancel[_roundId];
    }

    function tokenStatus(uint _roundId, address _founder, address _investor) external view returns(uint unlockedAmount, uint lockedAmount, uint withdrawnTokensByFounder){
        uint unlockedTokens = 0;
        uint lockedTokens = 0;
        uint withdrawnTokens = 0;
        if(!initialWithdrawalStatus[_roundId][_founder]){
            unlockedTokens = initialTokensForFounder[_roundId][_founder];
        }else{
            withdrawnTokens = initialTokensForFounder[_roundId][_founder];
        }
        for(uint i = 0; i < _milestone[_investor][_roundId].length; i++){   
            uint id = _milestone[_investor][_roundId][i]._num;
            if(milestoneApprovalStatus[_roundId][id] == 1 && !milestoneWithdrawalStatus[_roundId][id]){
                unlockedTokens += (totalTokensOfInvestor[_roundId][_investor] * _milestone[_investor][_roundId][i]._percent)/ 100;
            } else if(milestoneApprovalStatus[_roundId][id] == 1 && milestoneWithdrawalStatus[_roundId][_milestone[_investor][_roundId][i]._num]){
                uint beforeTax = (totalTokensOfInvestor[_roundId][_investor] * _milestone[_investor][_roundId][i]._percent) / 100;
                uint tax = (2 * beforeTax)/ 100;
                withdrawnTokens += beforeTax - tax;
            }
        }
        lockedTokens = totalTokensOfInvestor[_roundId][_investor] - investorWithdrawnTokens[_investor][_roundId] - withdrawnTokens - withdrawalFee[_roundId] - unlockedTokens;
        return(
            unlockedTokens,
            lockedTokens,
            withdrawnTokens
        );
    }

    function investorWithdrawnToken(address _investor, uint _roundId) external view returns(uint investorWithdrawnTokenNumber){
        return investorWithdrawnTokens[_investor][_roundId];
    }

    function readTaxFee(uint _roundId) external view returns(uint transactionFee){
        return withdrawalFee[_roundId];
    }

    function milestoneWithdrawStatus(uint _roundId, uint _milestoneId) external view returns(bool){
        return milestoneWithdrawalStatus[_roundId][_milestoneId];
    }

    function initialWithdrawStatus(uint _roundId, address _founder) external view returns(bool initialWithdraw){
        return initialWithdrawalStatus[_roundId][_founder];
    }

    function availableTaxTokens(address _tokenContract) external view returns(uint taxTokens){
        return taxedTokens[_tokenContract];
    }
}

contract FundLock{
    address public _contractOwner;
    mapping(uint => mapping(address => uint)) public _amount;

    constructor (address investor, uint roundId, uint amount, address privateRoundContractAd) {
        _contractOwner = msg.sender;
        _amount[roundId][investor] = amount;
        require(ERC20(PrivateRound(privateRoundContractAd).tokenContract(roundId)).approve(privateRoundContractAd,amount), "execution failed or reverted");
    }
}