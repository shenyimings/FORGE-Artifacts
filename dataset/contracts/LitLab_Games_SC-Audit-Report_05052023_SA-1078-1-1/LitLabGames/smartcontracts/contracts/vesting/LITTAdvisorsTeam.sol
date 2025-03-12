// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/Ownable.sol";

/// @title Vesting contract for advisors and team tokens
/// Advisors will have a 24 months period. Also can be added and removed with no restriction
/// There will be need 3 approvals from the 5 authorized wallets to withdraw team funds
contract LITTAdvisorsTeam is Ownable {
    using SafeERC20 for IERC20;

    uint256 constant public TEAM_AMOUNT = 420000000 * 10 ** 18;
    uint8 constant private MAX_SIGNATURES_TEAM = 3;
    uint8 constant private TEAM_WALLETS = 5;
    uint256 private constant ADVISORS_MONTHS = 24;
    uint256 private constant TEAM_MONTHS = 42;

    mapping(address => uint256) private advisors;
    mapping(address => uint256) private advisorsWithdrawn;
    mapping(address => uint256) private advisorsLastWithdrawn;

    mapping(address => bool) private teamWallets;
    address public teamWallet;
    uint256 public teamWithdrawn;
    uint256 public teamLastWithdraw;

    address[5] private approvalWallets;
    mapping(address => bool) private teamApprovals;
    uint8 public numTeamApprovals;
    
    address public immutable token;
    uint256 public listing_date;

    event ListingDated(uint256 indexed _listingDate);
    event AdvisorAdded(address indexed _wallet, uint256 _amount);
    event AdvisorRemoved(address indexed _wallet);
    event ApprovalWalletsSet(address[5] _approvalWallets);
    event TeamWalletSet(address indexed _teamWallet);
    event TeamWithdrawApproval(address indexed _approval);
    event TeamWithdrawApproved(address indexed _sender);
    event AdvisorWithdrawn(address indexed _wallet, uint256 _amount);
    event TeamWithdrawn(address indexed _wallet, uint256 _amount);
    event EmergencyWithdrawn();

    /// @notice Constructor
    /// @param _token LitlabGames token address
    /// @param _teamWallet Wallet where team tokens are sent when withdrawn
    /// @param _approvalWallets For team tokens, an approval of 3/5 wallets will be required
    constructor(address _token, address _teamWallet, address[TEAM_WALLETS] memory _approvalWallets) {
        require(_token != address(0), "ZeroAddress");
        require(_teamWallet != address(0), "ZeroAddress");
        for (uint256 i=0; i<TEAM_WALLETS; i++) require(_approvalWallets[i] != address(0), "ZeroAddress");

        token = _token;
        teamWallet = _teamWallet;
        approvalWallets = _approvalWallets;

        emit TeamWalletSet(_teamWallet);
        emit ApprovalWalletsSet(_approvalWallets);
    }

    /// @notice Set listing date to start the vesting period
    function setListingDate(uint256 _listingDate) external onlyOwner {
        require(_listingDate >= block.timestamp, "NoPastDate");
        require(listing_date == 0 || block.timestamp < listing_date, "CannotChangeAfterListing");
        listing_date = _listingDate;

        emit ListingDated(_listingDate);
    }

    /// @notice Add a new advisor
    function addAdvisor(address _wallet, uint256 _amount) external onlyOwner {
        require(_wallet != address(0), "ZeroAddress");
        require(_amount != 0, "BadAmount");

        advisors[_wallet] = _amount;

        emit AdvisorAdded(_wallet, _amount);
    }

    /// @notice Remove an advisor
    function removeAdvisor(address _wallet) external onlyOwner {
        require(_wallet != address(0), "ZeroAddress");

        delete advisors[_wallet];

        emit AdvisorRemoved(_wallet);
    }

    /// @notice Change the approval wallets
    function setApprovalWallets(address[5] calldata _approvalWallets) external onlyOwner {
        for (uint256 i=0;i<approvalWallets.length; i++) delete teamApprovals[approvalWallets[i]];
        numTeamApprovals = 0;
        
        for (uint256 i=0; i<TEAM_WALLETS; i++) require(_approvalWallets[i] != address(0), "ZeroAddress");
        approvalWallets = _approvalWallets;

        emit ApprovalWalletsSet(_approvalWallets);
    }

    /// @notice Set new team wallet
    function setTeamWallet(address _teamWallet) external onlyOwner {
        require(_teamWallet != address(0), "ZeroAddress");
        teamWallet = _teamWallet;

        emit TeamWalletSet(_teamWallet);
    }

    /// @notice The advisors can withdraw their tokens according to the vesting
    function advisorWithdraw() external {
        require(block.timestamp >= listing_date + 90 days, "TooEarly");
        require(advisors[msg.sender] != 0, "NotAdvisor");
        require(advisors[msg.sender] - advisorsWithdrawn[msg.sender] > 0, "NotAllowed");

        uint256 start = listing_date + 90 days;
        uint256 end = start + (ADVISORS_MONTHS * 30 days);
        uint256 amountToWithdraw;
        if (block.timestamp < end) {
            uint256 from = advisorsLastWithdrawn[msg.sender] == 0 ? start : advisorsLastWithdrawn[msg.sender];
            uint256 to = block.timestamp;
            uint256 tokensPerSecond = advisors[msg.sender] / (ADVISORS_MONTHS * 30 days);
            amountToWithdraw = (to - from) * tokensPerSecond;
        } else {
            // This is the last time advisor can withdraw, so he withdraws all their remaining tokens
            amountToWithdraw = advisors[msg.sender] - advisorsWithdrawn[msg.sender];
        }

        advisorsWithdrawn[msg.sender] += amountToWithdraw;
        advisorsLastWithdrawn[msg.sender] = block.timestamp;
        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit AdvisorWithdrawn(msg.sender, amountToWithdraw);
    }

    /// @notice Function for approve the team tokens withdraw
    function approveTeamWithdraw() external {
        bool authorized;
        uint256 walletsLength = approvalWallets.length;
        for (uint256 i=0; i<walletsLength; i++) {
            if (approvalWallets[i] == msg.sender) {
                authorized = true;
                break;
            }
        }
        require(authorized, "NotAuthorized");

        if (!teamApprovals[msg.sender]) {
            numTeamApprovals++;
            teamApprovals[msg.sender] = true;
            emit TeamWithdrawApproved(msg.sender);
        }
    }

    /// @notice The team can withdraw their tokens according to the vesting
    function teamWithdraw() external {
        require(block.timestamp >= listing_date + 180 days, "TooEarly");
        require(numTeamApprovals >= MAX_SIGNATURES_TEAM, "NeedMoreApprovals");
        require(TEAM_AMOUNT - teamWithdrawn > 0, "NotAllowed");
    
        numTeamApprovals = 0;
        uint256 walletsLength = approvalWallets.length;
        for (uint256 i=0; i<walletsLength; i++) delete teamApprovals[approvalWallets[i]];
        
        uint256 start = listing_date + 180 days;
        uint256 end = start + (TEAM_MONTHS * 30 days);
        uint256 amountToWithdraw;

        if (block.timestamp < end) {
            uint256 from = teamLastWithdraw == 0 ? start : teamLastWithdraw;
            uint256 to = block.timestamp > end ? end : block.timestamp;
            uint256 tokensPerSecond = (TEAM_AMOUNT) / (end - start);
            amountToWithdraw = (to - from) * tokensPerSecond;
        } else {
            // This is the last time team can withdraw, so he withdraws all their remaining tokens
            amountToWithdraw = TEAM_AMOUNT - teamWithdrawn;
        }
        
        teamWithdrawn += amountToWithdraw;
        teamLastWithdraw = block.timestamp;
        IERC20(token).safeTransfer(teamWallet, amountToWithdraw);

        emit TeamWithdrawn(msg.sender, amountToWithdraw);
    }

    /// @notice Get data to the dapp
    function getAdvisorData(
        address _wallet
    ) external view returns (uint256 amount, uint256 amountWithdrawn, uint256 end) {
        amount = advisors[_wallet];
        amountWithdrawn = advisorsWithdrawn[_wallet];
        end = listing_date + 90 days + (ADVISORS_MONTHS * 30 days);
    }

    /// @notice Quick way to know how many tokens are pending in the contract
    function getTokensInContract() external view returns(uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @notice If there's any problem, contract owner can withdraw all funds (are advisors and team funds)
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, balance);

        emit EmergencyWithdrawn();
    }
}
