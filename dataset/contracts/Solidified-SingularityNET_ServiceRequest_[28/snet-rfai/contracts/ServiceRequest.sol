pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract ServiceRequest{
    
    using SafeMath for uint256;
    
    struct Request {
        uint256 requestId;
        address requester;
        uint256 totalFund;
        bytes documentURI;
        
        uint256 expiration;
        uint256 endSubmission;
        uint256 endEvaluation;
        
        RequestStatus status;
        
        address[] stakeMembers;
        mapping(address => uint256) funds;
        
        address[] submitters;
        mapping(address => Solution) submittedSols;
        
        mapping(address => mapping(address => uint256)) votes;
    }

    // Open -> Rejected
    // Open -> Approved -> Completed (TODO: Yet to get the logic for completed state - checking it is needed)
    // Open -> Approved -> Closed
    enum RequestStatus { Open, Approved, Rejected, Completed, Closed }
    
    struct Solution {
        bytes solutionDocURI;
        uint256 totalVotes;
        
        bool isSubmitted;
        bool isShortlisted;
        bool isClaimed;
    }
    
    uint256 public nextRequestId;
    mapping (uint256 => Request) public requests;
    mapping (address => uint256) public balances;
    
    uint256 public minStake;
    uint256 public maxStakers;

    address public owner;
    
    address[] public memberKeys;
    struct Member {
        uint role; // 0-Normal member, 1-> Admin Member who can add other members
        bool status; // True -> Active, False -> InActive/Deleted
        bool exists; // To check the existstance of the Member
    }
    mapping(address => Member) public foundationMembers;
 
    ERC20 public token; // Address of token contract
    
    // Events
    event AddFoundationMember(address indexed member, uint role, bool status, address indexed actor);
    event CreateRequest(uint256 requestId, address indexed requester, uint256 expiration, uint256 amount, bytes documentURI);
    event UpdateRequest(uint256 requestId, address indexed requester, uint256 expiration, bytes documentURI);
    event ExtendRequest(uint256 indexed requestId, address indexed requester, uint256 expiration);
    event ApproveRequest(uint256 indexed requestId, address indexed approver, uint256 endSubmission, uint256 endEvaluation, uint256 expiration);
    event FundRequest(uint256 indexed requestId, address indexed staker, uint256 amount);
    event AddSolutionRequest(uint256 indexed requestId, address indexed submitter, bytes solutionDocURI);
    event VoteRequest(uint256 indexed requestId, address indexed voter, address indexed submitter);
    event ClaimRequest(uint256 indexed requestId, address indexed submitter, uint256 amount);
    event ClaimBackRequest(uint256 indexed requestId, address indexed stacker, uint256 amount);
    event CloseRequest(uint256 indexed requestId, address indexed actor);
    event RejectRequest(uint256 indexed requestId, address indexed actor);

    constructor (address _token, uint256 _minStake, uint256 _maxStakers)
    public
    {
        token = ERC20(_token);
        owner = msg.sender;
        nextRequestId = 0;
        minStake = _minStake;
        maxStakers = _maxStakers;
    }
  
    function deposit(uint256 value) 
    public
    returns(bool) 
    {
        require(token.transferFrom(msg.sender, address(this), value), "Unable to transfer token to the contract"); 
        balances[msg.sender] = balances[msg.sender].add(value);
        return true;
    }
    
    function withdraw(uint256 value)
    public
    returns(bool)
    {
        require(balances[msg.sender] >= value, "Insufficient balance in the escrow");
        require(token.transfer(msg.sender, value), "Unable to transfer token back to the account");
        balances[msg.sender] = balances[msg.sender].sub(value);
        return true;
    }
    
    function updateOwner(address newOwner) public returns(bool) {
        require(owner == msg.sender, "Invalid sender");
        require(newOwner != address(0), "Invalid owner address");
        
        owner = newOwner;
        
        return true;
    }

    function updateLimits(uint256 _minStake, uint256 _maxStakers) public returns(bool) {
        require(owner == msg.sender, "Invalid sender");
        minStake = _minStake;
        maxStakers = _maxStakers;
        return true;
    }
    
    function addOrUpdateFoundationMembers(address member, uint role, bool active) public returns (bool) {
        
        require(owner == msg.sender || (foundationMembers[msg.sender].role == 1 && foundationMembers[msg.sender].status), "Operation not allowed");
        require(member != address(0), "Invalid member address");
        require(role == 0 || role == 1, "Invalid role parameter");
        
        Member memory mem;
        if(!foundationMembers[member].exists) {
            memberKeys.push(member);
        }
        foundationMembers[member] = mem;
        foundationMembers[member].role = role;
        foundationMembers[member].status = active;
        foundationMembers[member].exists = true;
        
        emit AddFoundationMember(member, role, active, msg.sender);

        return true;
    }
    
    function createRequest(uint256 value, uint256 expiration, bytes memory documentURI) 
    public
    returns(bool) 
    {
        require(balances[msg.sender] >= value && value >= minStake, "Insufficient balance or min stake criteria not met");
        require(documentURI.length > 0, "Invalid document URI");
        require(expiration > block.number, "Invalid expiration");

        Request memory req;
        requests[nextRequestId] = req;
        
        requests[nextRequestId].requestId = nextRequestId;
        requests[nextRequestId].requester = msg.sender;
        requests[nextRequestId].totalFund = value;
        requests[nextRequestId].documentURI = documentURI;
        requests[nextRequestId].expiration = expiration;
        requests[nextRequestId].status = RequestStatus.Open;

        balances[msg.sender] = balances[msg.sender].sub(value);

        requests[nextRequestId].funds[msg.sender] = value;
        requests[nextRequestId].stakeMembers.push(msg.sender);
        
        emit CreateRequest(nextRequestId++, msg.sender, expiration, value, documentURI);

        return true;
    }

    function depositAndCreateRequest(uint256 value, uint256 expiration, bytes memory documentURI)
    public
    returns(bool)
    {
        require(deposit(value), "Unable to deposit into escrow");
        require(createRequest(value, expiration, documentURI), "Unable to create a new request");
        return true;
    }

    function updateRequest(uint256 requestId, uint256 expiration, bytes memory documentURI) 
    public
    returns(bool) 
    {

        require(documentURI.length > 0, "Invalid document URI");
        require(expiration > block.number, "Invalid expiration");

        Request storage req = requests[requestId];

        require(msg.sender == req.requester, "Invalid sender");
        require(req.status == RequestStatus.Open, "Operation not allowed at this stage");

        req.documentURI = documentURI;
        req.expiration = expiration;
        
        emit UpdateRequest(requestId, msg.sender, expiration, documentURI);

        return true;
    }

    /// the sender can extend the expiration of the request at any time
    function extendRequest(uint256 requestId, uint256 newExpiration) 
    public 
    returns(bool)
    {
        Request storage req = requests[requestId];

        require(msg.sender == req.requester, "Invalid sender");
        require(req.status == RequestStatus.Open, "Operation not allowed at this stage");
        require(newExpiration >= req.expiration, "Invalid expiration");

        req.expiration = newExpiration;

        emit ExtendRequest(requestId, msg.sender, newExpiration);

        return true;
    }
    
    // Anyone could add funds to the service request
    function addFundsToRequest(uint256 requestId, uint256 amount)
    public
    returns(bool)
    {
        
        Request storage req = requests[requestId];

        require(balances[msg.sender] >= amount && amount > 0 && (amount >= minStake || req.funds[msg.sender] >= minStake) );

        // Request should be Approved - Means in Progress
        require(req.status == RequestStatus.Approved, "Operation not allowed at this stage");
        
        // Request should not be expired
        require(block.number < req.expiration && block.number < req.endEvaluation, "Operation not allowed at this stage");

        // Check for Max Stakers only for new stake 
        require(req.stakeMembers.length < maxStakers || req.funds[msg.sender] > 0, "Exceeding max stakers limit");

        //tranfser amount from sender to the Service Request
        balances[msg.sender] = balances[msg.sender].sub(amount);
        req.totalFund = req.totalFund.add(amount);
        
        // Adding funds first time check
        if(req.funds[msg.sender] == 0){
            req.stakeMembers.push(msg.sender);
        } // else member already exists

        //Update the respective request funds
        req.funds[msg.sender] = req.funds[msg.sender].add(amount);
        
        emit FundRequest(requestId, msg.sender, amount);

        return true;
    }

    function extendAndAddFundsToRequest(uint256 requestId, uint256 newExpiration, uint256 amount)
    public
    {
        require(extendRequest(requestId, newExpiration), "Unable to extend the request");
        require(addFundsToRequest(requestId, amount), "Unable to add funds to the request");
    }
    
    function approveRequest(uint256 requestId, uint256 endSubmission, uint256 endEvaluation, uint256 newExpiration) public returns(bool) {
        
        // Should be foundation Member
        require(foundationMembers[msg.sender].status, "Invalid foundation member");
        
        Request storage req = requests[requestId];
        
        // Request should be active
        require(req.status == RequestStatus.Open, "Operation not allowed at this stage");
        
        // Request should not be expired -- We should allow this
        //require(req.expiration > block.number, "Invalid expiration");
        require(endSubmission > block.number && endSubmission < endEvaluation && endEvaluation < newExpiration && newExpiration >= req.expiration, "Invalid request stages" );
        
        req.status = RequestStatus.Approved;
        req.endSubmission = endSubmission;
        req.endEvaluation = endEvaluation;
        req.expiration = newExpiration;
        
        emit ApproveRequest(requestId, msg.sender, endSubmission, endEvaluation, newExpiration);

        return true;
    }
    
    function rejectRequest(uint256 requestId) public returns(bool) {
        
        // Should be foundation Member
        require(foundationMembers[msg.sender].status, "Invalid foundation member");
        
        Request storage req = requests[requestId];
        
        // Request should be active
        require(req.status == RequestStatus.Open, "Opeartion not allowed at this stage");
        
        // Change the status of the Request to Rejected
        req.status = RequestStatus.Rejected;

        emit RejectRequest(requestId, msg.sender);

        return true;
    }

    function closeRequest(uint256 requestId) public returns(bool) {
        
        Request storage req = requests[requestId];

        // Should be active foundation Member or Request Owner
        require((req.status == RequestStatus.Approved && foundationMembers[msg.sender].status) ||  (req.status == RequestStatus.Open && req.requester == msg.sender), "Invalid sender");  
        
        // Change the status of the Request to Closed
        req.status = RequestStatus.Closed;
        
        emit CloseRequest(requestId, msg.sender);
    }
    
    function createOrUpdateSolutionProposal(uint256 requestId, bytes memory solutionDocURI)
    public
    returns(bool)
    {

        require(solutionDocURI.length > 0);

        Request storage req = requests[requestId];

        // Request should be active
        require(req.status == RequestStatus.Approved, "Operation is not allowed at this stage");
        
        // Request should not be expired
        require(block.number < req.expiration && block.number <= req.endSubmission, "Exceeding the submission stage");
        
        Solution memory sol;

        // Check if already user submitted the solution
        if(!req.submittedSols[msg.sender].isSubmitted) {
            req.submitters.push(msg.sender);
        }
        // Create or Update the Submitted Solution
        req.submittedSols[msg.sender] = sol;
        req.submittedSols[msg.sender].solutionDocURI = solutionDocURI;
        req.submittedSols[msg.sender].isSubmitted = true;
        
        emit AddSolutionRequest(requestId, msg.sender, solutionDocURI);

        return true;
        
    }

    // Only users who has stake can vote
    // Foundation members can vote => Shortlist
    function vote(uint256 requestId, address solutionSubmitter) public returns (bool) {
        
        Request storage req = requests[requestId];
        
        // Request should be active
        require(req.status == RequestStatus.Approved, "Opration not allowed at this stage");
        
        // Request should not be expired
        require(block.number < req.expiration && block.number > req.endSubmission && block.number <= req.endEvaluation, "Exceeding the evaluation stage");
        
        // Should be foundation Member or Staking Member to Vote
        require(foundationMembers[msg.sender].status || req.funds[msg.sender] > 0, "Invalid sender");
        
        // Check for solution Submitter status and cannot for own submission
        require(req.submittedSols[solutionSubmitter].isSubmitted && msg.sender != solutionSubmitter);
        
        req.submittedSols[solutionSubmitter].totalVotes += 1;
        
        submitVote(requestId, solutionSubmitter, foundationMembers[msg.sender].status);
        
        emit VoteRequest(requestId, msg.sender, solutionSubmitter);
        
        return true;
    }

    function submitVote(uint256 requestId, address solutionSubmitter, bool isFromFoundation) 
    internal 
    {
        
        Request storage req = requests[requestId];

        if(isFromFoundation && !req.submittedSols[solutionSubmitter].isShortlisted) {
            // 0x0 contains foundation shortlisted solutions
            req.votes[address(0)][address(0)] += 1;
            req.votes[address(0)][solutionSubmitter] = 1;
            req.submittedSols[solutionSubmitter].isShortlisted = true;
        }
        
        if(req.funds[msg.sender] > 0 && req.votes[msg.sender][solutionSubmitter] == 0)
        {
            req.votes[msg.sender][address(0)] += 1;
            req.votes[msg.sender][solutionSubmitter] = 1;
        }
    }
    
    function requestClaimBack(uint256 requestId) public returns (bool) {

        Request storage req = requests[requestId];
        
        // Request should have funds
        require(req.totalFund > 0, "No fund to claim");

        // Should have stake
        require(req.funds[msg.sender] > 0, "Invalid sender");

        // Approved or Open request should be expiried or Request is closed / rejected
        require((block.number > req.expiration && (req.status == RequestStatus.Approved || req.status == RequestStatus.Open )) || req.status == RequestStatus.Closed || req.status == RequestStatus.Rejected, "Claims not allowed at this stage");
        
        uint256 claimBackAmt;
        claimBackAmt = req.funds[msg.sender];
        balances[msg.sender] = balances[msg.sender].add(req.funds[msg.sender]);
        req.totalFund = req.totalFund.sub(req.funds[msg.sender]);
        req.funds[msg.sender] = 0;
        
        emit ClaimBackRequest(requestId, msg.sender, claimBackAmt);

        return true;
    }

    function requestClaim(uint256 requestId) 
    public
    returns (bool)
    {
        uint256 fundationVotes;
        uint256 userStake;
        uint256 totalClaim;
        uint256 userVotes;
        address stakeMember;
        Request storage req = requests[requestId];
        
        // Request should be active and should have funds
        require(req.status == RequestStatus.Approved && req.totalFund > 0, "Operation not allowed at this stage");
        
        // Request should complete the eveluation and should not expire
        require(block.number > req.endEvaluation && block.number < req.expiration, "Operation not allowed at this stage");
        
        // Should be Solution Submitter Only and should have atleast one vote
        require(req.submittedSols[msg.sender].isSubmitted && !req.submittedSols[msg.sender].isClaimed, "Need to be an unclaimed solution submitter");
        
        fundationVotes = req.votes[address(0)][address(0)];
        for(uint256 i=0; i<req.stakeMembers.length;i++) {
            userVotes = 0;
            stakeMember = req.stakeMembers[i];
            userStake = req.funds[stakeMember];

            if(userStake > 0) {
                if(req.votes[stakeMember][msg.sender] > 0 && req.votes[stakeMember][address(0)] > 0) {
                    userVotes = req.votes[stakeMember][address(0)].sub(req.votes[stakeMember][stakeMember]);
                }
                else if(fundationVotes > 0 && req.votes[address(0)][msg.sender] > 0 && req.votes[stakeMember][address(0)] == 0) {
                    userVotes = fundationVotes.sub(req.votes[stakeMember][stakeMember]);               
                }
                if(userVotes > 0) {
                    userStake = userStake.div(userVotes);
                    req.funds[stakeMember] = req.funds[stakeMember].sub(userStake);
                    totalClaim = totalClaim.add(userStake);
                    req.votes[stakeMember][stakeMember] = req.votes[stakeMember][stakeMember].add(1);
                }
            }
        }
        
        req.totalFund = req.totalFund.sub(totalClaim);
        balances[msg.sender] = balances[msg.sender].add(totalClaim);
        req.submittedSols[msg.sender].isClaimed = true;

        emit ClaimRequest(requestId, msg.sender, totalClaim);
        
        return true;
    }


    // Getters
    function getFoundationMemberKeys() public view returns (address[] memory) {
        return memberKeys;
    }

    function getServiceRequestById(uint256 reqId) public view 
    returns (bool found, uint256 requestId, address requester, uint256 totalFund, bytes memory documentURI, uint256 expiration, uint256 endSubmission, uint256 endEvaluation, RequestStatus status, address[] memory stakeMembers, address[] memory submitters) 
    {
        Request memory req = requests[reqId];

        if(req.requester == address(0)) {
            found = false;
        } else {
            found = true;
            requestId = req.requestId;
            requester = req.requester; 
            totalFund = req.totalFund; 
            documentURI = req.documentURI; 
            expiration = req.expiration; 
            endSubmission = req.endSubmission;
            endEvaluation = req.endEvaluation; 
            status = req.status; 
            stakeMembers = req.stakeMembers; 
            submitters = req.submitters;
        }
    }

    function getSubmittedSolutionById(uint256 requestId, address submitter) public view 
    returns (bool found, bytes memory solutionDocURI, uint256 totalVotes, bool isSubmitted, bool isShortlisted, bool isClaimed)
    {
        Request storage req = requests[requestId];

        if(req.submittedSols[submitter].isSubmitted == false) {
            found = false;
        } else {
            found = true;
            solutionDocURI = req.submittedSols[submitter].solutionDocURI;
            totalVotes = req.submittedSols[submitter].totalVotes;
            isSubmitted = req.submittedSols[submitter].isSubmitted;
            isShortlisted =  req.submittedSols[submitter].isShortlisted;
            isClaimed = req.submittedSols[submitter].isClaimed;
        }
    }

    function getStakeById(uint256 requestId, address staker) public view 
    returns (bool found, uint256 stake)
    {
        Request storage req = requests[requestId];
        if(req.funds[staker] == 0) {
            found = false;
        } else {
            found = true;
            stake = req.funds[staker];
        }
    }
  
}