// SPDX-License-Identifier: MIT
pragma abicoder v2;
pragma solidity ^0.8.9;
import "./Founder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Vesting is Initializable, UUPSUpgradeable, OwnableUpgradeable{

    error zeroAddress();
    error tokenAlreadyExist();
    error tokenNotSupported();
    error vestIdAlreadyLinkedToFounder();
    error founderNotRegistered();
    error addressNotMatched();
    error tgeDateNotReached();
    error alreadyWithdrawn();
    error installmentNotUnlocked(); 
    error vestIdAlreadyLinkedToInvestor();
    error vestIdNotLinkedToInvestor();
    error vestIdAlreadyTaken();
    error enterPossibleData();
    error installmentAlreadySet();
    error setInstallmentFirst();

    // STATE VARIABLES:
    address public contractOwner;
    address private FounderContract;
    address[] private tokenContractAddress;

    // EVENTS
    event LinearDepositSingleInvestor(address from, address to, uint amount);
    event LinearDepositBulk(address from, uint id, string success);
    event tgeWithdrawn(address to, uint amount);
    event installmentWithdrawn(address to, uint amount);
    event batchWithdrawTokens(address to, uint amount);
    event setNonLinearStatus(address from, address to, uint id);
    event depositNonLinearTokens(address from, address to, uint amount);

    // MODIFIERS:
    modifier onlyAdmin(){
        require(msg.sender == contractOwner,"Sender is not the owner of this contract");
        _;
    }

    // STRUCTS
    struct vestingSchedule{
        mapping(uint => mapping(address => uint)) depositsOfFounderTokensToInvestor;   // 1 vestingId, address(Investor) = amount (total by founder)
        mapping(uint => mapping(address => uint)) depositsOfFounderCurrentTokensToInvestor;
        mapping(uint => mapping(address => uint)) tgeDate;                          // vestId, investor = date
        mapping(uint => mapping(address => uint)) vestingStartDate;                 // vestingId, investor, vestingStarDate (unix)
        mapping(uint => mapping(address => uint)) vestingMonths;                    // vestingId, investor, vestingMonths (plain days)
        mapping(uint => mapping(address => uint)) tgeFund;                          // vestId, investor - tge percentage amt
        mapping(uint => mapping(address => uint)) remainingFundForInstallments;     // vestId, investor = remaining of tge
        mapping(uint => mapping(address => uint)) installmentAmount;                // vestId, investor = 800/24 =  
    }

    struct installment{
        mapping(uint => uint) _date;
        mapping(uint => bool) _status; 
        mapping(uint => uint) _fund;
    }

    struct investors{
        address _investor;
        uint _tokens;
        uint _tgeFund;
    }

    struct forFounder{
        address _founder;
        address _founSM;
        address _founderCoinAddress;
    }

    struct I{
        address _investor;
        uint _fund;
    }

    struct due{
        uint256 _dateDue;
        uint256 _fundDue;
    }

    struct depositLinear{
        address _coinContractAd;
        address _investor;
        uint _vestId;
        uint _amount;
        uint _tgeFund;
        uint _tgeDate;
        uint _vestingStartDate;
        uint _vestingMonths;
        uint _vestingMode;
    }

    struct linearBulk{
        address _coinContractAd;
        uint _vestId;
        uint _tgeDate;
        uint _vestingStartDate;
        uint _vestingMonths;
        uint _vestingMode;
    }

    struct withdrawTGE{
        address _coinContractAd;
        address _founder;
        address _investor;
        uint _vestId;
    }

    struct withdrawInstallmentTokens{
        address _coinContractAd;
         address _founder; 
        address _investor;
        uint _vestId;
        uint _index;
    }

    struct setNonLinear{
        address _founder;
        address _investor;
        uint _vestId;
    }

    struct withdrawBatchTokens{
        address _coinContractAd;
        address _founder;
        address _investor; 
        uint _vestId;
    }

    struct depositNonLinear{
        address _coinContractAd;
        address _founder; 
        address _investor;
        uint _vestId;
        uint _amount;
        uint _tgeDate;
        uint _tgeFund;
    }

    // MAPPINGS
    mapping(address => bool) private addressExist;
    mapping(address => vestingSchedule) vs;       // vestid -> investor -> installments[date: , fund]
    mapping(uint =>mapping(address => installment)) vestingDues;    // vestId => investorAd => installment
    mapping(uint => mapping(address => uint)) installmentCount; // vestId => investorAd => installmentCount
    mapping(uint => mapping(address => uint)) private investorWithdrawBalance;
    mapping(address => mapping(uint => bool)) private isVestIdForFounder;
    mapping(uint256 => bool) private vestIdExist;
    mapping(address => mapping(uint => bool)) private isVestIdForInvestor;
    mapping(uint => bool) private vestIdAlreadyLinked;
    mapping(uint => mapping(address => bool)) private installmentSet;

    /**
        * initialize().
        * This method is for UUPS upgrade. 
    */

    function initialize() external initializer{
      ///@dev as there is no constructor, we need to initialise the OwnableUpgradeable explicitly
       __Ownable_init();
       contractOwner = msg.sender;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
        * Whitelist contract this is necessary for Founder:
        * @param _contractAddressFounder This sets the FounderContract Address.
    */
    function whitelistFounderContract(address _contractAddressFounder) external onlyAdmin{
        if(_contractAddressFounder == address(0)){ revert zeroAddress();}
        FounderContract = _contractAddressFounder;
    }

    /**
        * whitelistToken.  eg: FTK,DAI,USDC
        * Whitelist the token address, so that only tokensfrom the whitelist works.
        * @param _tokenContract Set the token contract address to be logged to the smart contract.
    */
    function whitelistToken(address _tokenContract) external onlyAdmin{
        if(_tokenContract == address(0)){ revert zeroAddress();}
        if(addressExist[_tokenContract] == true){ revert tokenAlreadyExist();}
        addressExist[_tokenContract] = true;
        tokenContractAddress.push(_tokenContract);
    }

    /**
        * LINEAR DEPOSIT - depositFounderLinearTokens
        * The expected input type is struct.
        * _coinContractAd - Set the token contract address
        * _investor - Set the investor address.
        * _vestId - Set the vestId.
        * _amount - Set the amount of token.
        * _tgeFund - Set the tge fund
        * _tgeDate - Set the tgeDate.
        * _vestingStartDate - Set the vesting start date.
        * _vestingMonths - Set the vesting months.
        * _vestingMode - Set the vesting mode.
        * @param _input - Use struct format.
    */
    function depositFounderLinearTokens(depositLinear memory _input) external {
        depositLinear memory data = _input;
        if(addressExist[data._coinContractAd] != true){ revert tokenNotSupported();}
        if(data._tgeFund <=0 || data._amount <= 0 || data._tgeDate < block.timestamp || data._vestingStartDate < block.timestamp || data._vestingMonths <=0 || data._vestingMode <=0){ revert enterPossibleData();}
        Founder founder = Founder(FounderContract);
        if( vestIdAlreadyLinked[data._vestId] == true){ revert vestIdAlreadyTaken();}
        vestIdAlreadyLinked[data._vestId] = true;
        if(isVestIdForFounder[msg.sender][data._vestId] == true){ revert vestIdAlreadyLinkedToFounder();}
        isVestIdForFounder[msg.sender][data._vestId] = true;
        isVestIdForInvestor[data._investor][data._vestId] = true;
        uint _founderDeposit;
        if(data._vestingMonths == 0){
            data._vestingMonths = 1;
        }
        if(founder.verifyFounder(msg.sender)){
            vs[msg.sender].depositsOfFounderTokensToInvestor[data._vestId][data._investor] = data._amount; // 1 deposit
            _founderDeposit = vs[msg.sender].depositsOfFounderTokensToInvestor[data._vestId][data._investor];
            vs[msg.sender].depositsOfFounderCurrentTokensToInvestor[data._vestId][data._investor] = data._amount;
            vs[msg.sender].tgeDate[data._vestId][data._investor] = data._tgeDate; // 3 unix
            vs[msg.sender].vestingStartDate[data._vestId][data._investor] = data._vestingStartDate; // 4 unix
            vs[msg.sender].vestingMonths[data._vestId][data._investor] = data._vestingMonths; // 5 plain
            vs[msg.sender].tgeFund[data._vestId][data._investor] = data._tgeFund;
            vs[msg.sender].remainingFundForInstallments[data._vestId][data._investor] = data._amount - vs[msg.sender].tgeFund[data._vestId][data._investor];
            vs[msg.sender].installmentAmount[data._vestId][data._investor] = vs[msg.sender].remainingFundForInstallments[data._vestId][data._investor] / data._vestingMonths;
            for(uint i = 0; i < data._vestingMonths; i++){
                vestingDues[data._vestId][data._investor]._date[i+1] = data._vestingStartDate + (i * data._vestingMode * 1 days);
                vestingDues[data._vestId][data._investor]._status[i+1] = false;
                vestingDues[data._vestId][data._investor]._fund[i+1] =  vs[msg.sender].installmentAmount[data._vestId][data._investor];
            }
            installmentCount[data._vestId][data._investor] = data._vestingMonths;
            require(ERC20(data._coinContractAd).transferFrom(msg.sender, address(this), data._amount), "transaction failed or reverted");
            emit LinearDepositSingleInvestor(msg.sender,data._investor,data._amount);
        }else{
            revert founderNotRegistered();
        }
    }

    /**
        * LINEAR DEPOSIT - depositFounderLinearTokensToInvestors
        * use the mapping to get the inputs of investor based on vestid and index number subject to the struct array.
        * getting struct value in array and using investors array so using double array in the smart contract.
        * _coinContractAd - Set the token contract address.
        * _vestId - Set the vestId.
        * _tgeDate - Set the tgeDate.
        * _vestingStartDate - Set the vesting start date.
        * _vestingMonths - Set the vesting months.
        * _vestingMode - Set the vesting mode. 
        * @param _input - Use struct format.
        * @param _investors Set array of investor address and fund allocated for them.
    */
    function depositFounderLinearTokensToInvestors(linearBulk memory _input, investors[] memory _investors) external {
        linearBulk memory data = _input;
        if(addressExist[data._coinContractAd] != true){ revert tokenNotSupported();}
        if(data._tgeDate < block.timestamp || data._vestingStartDate < block.timestamp || data._vestingMonths <=0 || data._vestingMode <=0){ revert enterPossibleData();}
        Founder founder = Founder(FounderContract);
        require(founder.verifyFounder(msg.sender), "The address is not registered in the 'Founder' contract");
        if( vestIdAlreadyLinked[data._vestId] == true){ revert vestIdAlreadyTaken();}
        vestIdAlreadyLinked[data._vestId] = true;
        if(isVestIdForFounder[msg.sender][data._vestId] == true){ revert vestIdAlreadyLinkedToFounder();}
        isVestIdForFounder[msg.sender][data._vestId] = true;
        uint totalTokens = 0;
        if(data._vestingMonths == 0){
            data._vestingMonths = 1;
        }
        for(uint i = 0; i < _investors.length; i++){
            isVestIdForInvestor[_investors[i]._investor][data._vestId] = true;
            address _investor = _investors[i]._investor;
            uint _amount = (_investors[i]._tokens * (10**18))/10000;
            totalTokens += _amount;
            vs[msg.sender].depositsOfFounderTokensToInvestor[data._vestId][_investor] = _amount; // 1 deposit
            vs[msg.sender].depositsOfFounderCurrentTokensToInvestor[data._vestId][_investor] = _amount;
            vs[msg.sender].tgeDate[data._vestId][_investor] = data._tgeDate; // 3 unix
            vs[msg.sender].vestingStartDate[data._vestId][_investor] = data._vestingStartDate; // 4 unix
            vs[msg.sender].vestingMonths[data._vestId][_investor] = data._vestingMonths; // 5 plain
            vs[msg.sender].tgeFund[data._vestId][_investor] = (_investors[i]._tgeFund * (10**18))/10000;
            vs[msg.sender].remainingFundForInstallments[data._vestId][_investor] = _amount - vs[msg.sender].tgeFund[data._vestId][_investor];
            vs[msg.sender].installmentAmount[data._vestId][_investor] = vs[msg.sender].remainingFundForInstallments[data._vestId][_investor] / data._vestingMonths;
            require(ERC20(data._coinContractAd).transferFrom(msg.sender, _investors[i]._investor, (_investors[i]._tokens * (10**18))/10000), "transaction failed or reverted");
            for(uint j = 0; j < data._vestingMonths; j++){
                vestingDues[data._vestId][_investor]._date[j+1] = data._vestingStartDate + (j * data._vestingMode * 1 days);
                vestingDues[data._vestId][_investor]._status[j+1] = false;
                vestingDues[data._vestId][_investor]._fund[j+1] =  vs[msg.sender].installmentAmount[data._vestId][_investor];
            }
            installmentCount[data._vestId][_investor] = data._vestingMonths;
            emit LinearDepositBulk(msg.sender, data._vestId, "deposit Completed");
        }
    }

    /**
        * withdrawTGEFund
        * _coinContractAd - Set the token contract address.
        * _founder - Set the founder address.
        * _investor - Set the investor address.
        * _vestId - Set the vestId.
        * @param _input - Use struct format.
    */
    function withdrawTGEFund(withdrawTGE memory _input) external {
        withdrawTGE memory data = _input;
        if(addressExist[data._coinContractAd] != true){ revert tokenNotSupported();}
        if(msg.sender != data._investor){ revert addressNotMatched();}
        if(isVestIdForInvestor[data._investor][data._vestId] != true){ revert vestIdNotLinkedToInvestor();}
        if(block.timestamp >= vs[data._founder].tgeDate[data._vestId][data._investor]){
            vs[data._founder].depositsOfFounderCurrentTokensToInvestor[data._vestId][data._investor] -= vs[data._founder].tgeFund[data._vestId][data._investor];
            investorWithdrawBalance[data._vestId][data._investor] += vs[data._founder].tgeFund[data._vestId][data._investor];
            require(ERC20(data._coinContractAd).transfer(msg.sender, vs[data._founder].tgeFund[data._vestId][data._investor]), "transaction failed or reverted");
            emit tgeWithdrawn(msg.sender, vs[data._founder].tgeFund[data._vestId][data._investor]);
            vs[data._founder].tgeFund[data._vestId][data._investor] = 0; 
        }else{
            revert tgeDateNotReached();
        }
    }

    /**
        * withdrawInstallmentAmount
        * Based on months the installment amount is calculated, once the withdrawn is done deduct.
        * _coinContractAd - Set the token contract address.
        * _founder - Set the founder address.
        * _investor - Set the investor address.
        * _vestId - Set the vestId.
        * _index - Set the index number.
        * @param _input - Use struct format.
    */
    function withdrawInstallmentAmount(withdrawInstallmentTokens memory _input) external {
        withdrawInstallmentTokens memory data = _input;
        if(addressExist[data._coinContractAd] != true){ revert tokenNotSupported();}
        if(msg.sender != data._investor){ revert addressNotMatched();}
        if(isVestIdForInvestor[data._investor][data._vestId] != true){ revert vestIdNotLinkedToInvestor();}
        uint amt;
        if(block.timestamp >= vestingDues[data._vestId][data._investor]._date[data._index]){
            if(!vestingDues[data._vestId][data._investor]._status[data._index]){
                amt = vestingDues[data._vestId][data._investor]._fund[data._index];
                vs[data._founder].remainingFundForInstallments[data._vestId][data._investor] -= amt;
                vs[data._founder].depositsOfFounderCurrentTokensToInvestor[data._vestId][data._investor] -= amt;
                investorWithdrawBalance[data._vestId][data._investor] += amt;
                vestingDues[data._vestId][data._investor]._status[data._index] = true;
                require(ERC20(data._coinContractAd).transfer(data._investor, amt), "transaction failed or executed");   // update this line
                emit installmentWithdrawn(data._investor, amt);
            }else{
                revert alreadyWithdrawn();
            }
        }else{
            revert installmentNotUnlocked(); 
        }
    }

    /**
        * withdrawBatch 
        * _coinContractAd - Set the token contract address
        * _founder - Set the founder address.
        * _investor - Set the investor address.
        * _vestId - Set the vestId.
        * @param _input - Use struct format.
    */
    function withdrawBatch(withdrawBatchTokens memory _input) external {
        withdrawBatchTokens memory data = _input;
        if(msg.sender != data._investor){ revert addressNotMatched();}
        if(isVestIdForInvestor[data._investor][data._vestId] != true){ revert vestIdNotLinkedToInvestor();}
        if(installmentCount[data._vestId][data._investor] != 0){
            uint unlockedAmount = 0;
            for(uint i = 1; i <= installmentCount[data._vestId][data._investor]; i++){
                if(vestingDues[data._vestId][data._investor]._date[i] <= block.timestamp && !vestingDues[data._vestId][data._investor]._status[i]){
                    unlockedAmount += vestingDues[data._vestId][data._investor]._fund[i];
                    vestingDues[data._vestId][data._investor]._status[i] = true;
                }
            }
            vs[data._founder].remainingFundForInstallments[data._vestId][data._investor] -= unlockedAmount;
            if(block.timestamp >= vs[data._founder].tgeDate[data._vestId][data._investor]){
                unlockedAmount += vs[data._founder].tgeFund[data._vestId][data._investor];
                vs[data._founder].tgeFund[data._vestId][data._investor] = 0; 
            }
            vs[data._founder].depositsOfFounderCurrentTokensToInvestor[data._vestId][data._investor] -= unlockedAmount;
            investorWithdrawBalance[data._vestId][data._investor] += unlockedAmount;
            require(ERC20(data._coinContractAd).transfer(msg.sender, unlockedAmount), "transaction failed or executed");
            emit batchWithdrawTokens(msg.sender, unlockedAmount);
        }
    }

    
    // Method: NON-LINEAR:
    /**
        * setNonLinearInstallments
        * create an seperate array for date and fund [][]
        * _founder - Set the founder address.
        * _investor - Set the investor address.
        * _vestId - Set the vestId.
        * @param _input - Use struct format.
        * @param _dues - Set the due setup.
    */            
    function setNonLinearInstallments(setNonLinear memory _input, due[] memory _dues) external {
        setNonLinear memory data = _input;
        if(msg.sender != data._founder){ revert addressNotMatched();}
        Founder founder = Founder(FounderContract);
        if(installmentSet[data._vestId][data._investor] == true){ revert installmentAlreadySet();}
        installmentSet[data._vestId][data._investor] = true;
        if(founder.verifyFounder(data._founder)){
            uint duesAmount;
            for(uint i = 0; i < _dues.length; i++){     // error with for loop status: resolved.
                vestingDues[data._vestId][data._investor]._date[i+1] = _dues[i]._dateDue;  //_dues[i]._dateDue;
                vestingDues[data._vestId][data._investor]._status[i+1] = false;
                vestingDues[data._vestId][data._investor]._fund[i+1] = (_dues[i]._fundDue * (10**18))/10000;  // added the 10 ** 18 condition here.
                duesAmount += vestingDues[data._vestId][data._investor]._fund[i+1];
            }
            installmentCount[data._vestId][data._investor] = _dues.length;
            emit setNonLinearStatus(data._founder,data._investor,data._vestId);
        }else{
            revert founderNotRegistered();
        }
    }

    /**
        * NON-LINEAR DEPOSIT - depositFounderNonLinearTokens
        * _coinContractAd - Set the token contract address
        * _founder - Set the founder address.
        * _investor - Set the investor address.
        * _vestId - Set the vestId.
        * _amount - Set the amount of token.
        * _tgeDate - Set the tgeDate.
        * _tgeFund - Set the tge fund.
        * @param _input - Use struct format.
    */
    function depositFounderNonLinearTokens(depositNonLinear memory _input) external{
        depositNonLinear memory data = _input;
        if(msg.sender != data._founder){ revert addressNotMatched();}
        if(data._amount <= 0 || data._tgeDate < block.timestamp || data._tgeFund <=0){ revert enterPossibleData();}
        Founder founder = Founder(FounderContract);
        if( vestIdAlreadyLinked[data._vestId] == true){ revert vestIdAlreadyTaken();}
        vestIdAlreadyLinked[data._vestId] = true;
        if(isVestIdForFounder[msg.sender][data._vestId] == true){ revert vestIdAlreadyLinkedToFounder();}
        isVestIdForFounder[msg.sender][data._vestId] = true;
        isVestIdForInvestor[data._investor][data._vestId] = true;
        if(installmentSet[data._vestId][data._investor] != true){ revert setInstallmentFirst();}
        uint _founderDeposit;
        if(founder.verifyFounder(data._founder)){
            vs[data._founder].depositsOfFounderTokensToInvestor[data._vestId][data._investor] = data._amount; // 1 deposit
            _founderDeposit = vs[data._founder].depositsOfFounderTokensToInvestor[data._vestId][data._investor];
            vs[data._founder].depositsOfFounderCurrentTokensToInvestor[data._vestId][data._investor] = data._amount;
            vs[data._founder].tgeDate[data._vestId][data._investor] = data._tgeDate; // 3 unix
            vs[data._founder].tgeFund[data._vestId][data._investor] = data._tgeFund;
            vs[data._founder].remainingFundForInstallments[data._vestId][data._investor] = data._amount - vs[data._founder].tgeFund[data._vestId][data._investor];
            require(ERC20(data._coinContractAd).transferFrom(data._founder, address(this), data._amount), "transaction failed or reverted");
            emit depositNonLinearTokens(data._founder, address(this), data._amount);
        }else{
            revert founderNotRegistered();
        }
    }

    // READ FUNCTIONS:
    function currentEscrowBalanceOfInvestor(address _founder, uint _vestId, address _investor) external view returns(uint){
        return vs[_founder].depositsOfFounderCurrentTokensToInvestor[_vestId][_investor];
    }

    function investorTGEFund(address _founder, uint _vestId, address _investor) external view returns(uint){
        return vs[_founder].tgeFund[_vestId][_investor];
    }

    function investorInstallmentFund(uint _vestId, uint _index, address _investor) external view returns(uint,uint){
        return (vestingDues[_vestId][_investor]._fund[_index],
                vestingDues[_vestId][_investor]._date[_index]
        );
    }

    function investorWithdrawnFund(address _investor, uint _vestId) external view returns(uint){
        return investorWithdrawBalance[_vestId][_investor];
    }

    function returnRemainingFundExcludingTGE(address _founder, address _investor, uint _vestId) external view returns(uint){
        return vs[_founder].remainingFundForInstallments[_vestId][_investor];
    }

    function investorUnlockedFund(address _founder, address _investor, uint _vestId) external view returns(uint){
        uint unlockedAmount = 0;
        if(block.timestamp >= vs[_founder].tgeDate[_vestId][_investor]){
            unlockedAmount += vs[_founder].tgeFund[_vestId][_investor];
        }
        for(uint i = 1; i <= installmentCount[_vestId][_investor]; i++){
            if(vestingDues[_vestId][_investor]._date[i] <= block.timestamp && !vestingDues[_vestId][_investor]._status[i]){
                unlockedAmount += vestingDues[_vestId][_investor]._fund[i];
            }
        }
        return unlockedAmount;
    }
}