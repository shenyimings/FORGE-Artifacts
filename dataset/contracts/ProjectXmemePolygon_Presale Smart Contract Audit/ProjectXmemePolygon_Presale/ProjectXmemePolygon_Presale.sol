// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
contract ProjectXmemePolygon_Presale is Ownable {


    // Define the token address (assuming it's an ERC20 token)
    address public usdt;

    // Define the total supply
    uint256 public totalSupply = 4000000000 * 10**18; // Total supply in wei
    mapping(address => Purchase[]) public purchases;
        uint256 public maxpurchase = 1000000000 * 10**18; // Total supply in wei

    // Define presale round details
    struct PresaleRound {
        uint256 price; // Price in wei
        uint256 amount; // Amount of tokens
        uint256 cliff; // Cliff in seconds
        uint256 sold; // Amount of tokens sold in this round
    }
     struct Purchase {
        uint256 round;
        uint256 amount;
        bool claimed;
        uint256 buyat;
    }
    PresaleRound[4] public rounds;

    // Mapping to track claimed tokens
    mapping(address => mapping(uint8 => bool)) public claimed;

    // Variable to track the current round
    uint8 public currentRound;
    uint256 public tokenSold = 0;
    IERC20 public ProjectXmeme = IERC20(0xe4F1BDF9E4f37F7DB5045129D983f005AaEd7AEA);
    IERC20 public USDTADD = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F); 
    uint256 TGEValue = 1726790774;
    // Constructor
    constructor() {
        // Define presale rounds
        rounds[0] = PresaleRound(33333333300000000000000, 250000000000000000000000000, 60 days, 0); // Round 1: $0.00003, 250,000,000 tokens, 2 months cliff
        rounds[1] = PresaleRound(20000000000000000000000, 500000000000000000000000000, 30 days, 0); // Round 2: $0.00005, 500,000,000 tokens, 1 month cliff
        rounds[2] = PresaleRound(14285714000000000000000, 1250000000000000000000000000, 0, 0); // Round 3: $0.00007, 1,250,000,000 tokens, no cliff
        rounds[3] = PresaleRound(10000000000000000000000, 2000000000000000000000000000, 0, 0); // Round 4: $0.0001, 2,000,000,000 tokens, no cliff

        // Initialize current round to 0 (Round 1)
        currentRound = 0;
    }

    // Function to purchase tokens during the presale
    function purchaseTokens(uint256 usdtAmount) external payable {

        // Ensure presale is active
        require(currentRound < 4, "Presale end");
        uint256 amount = usdtAmount / 1000000000000;

        require(purchases[msg.sender].length == 0, "Already Purchased");
        uint256 tokensToBuy = rounds[currentRound].price * usdtAmount;
        tokenSold += tokensToBuy / 1000000000000000000;
        require(tokensToBuy / 1000000000000000000 <= maxpurchase , "Maximum Purchase of 1000000000");
        purchases[msg.sender].push(Purchase(currentRound, tokensToBuy / 1000000000000000000, false,block.timestamp));
        require(USDTADD.transferFrom(msg.sender,address(this),amount), "No approval");

         if (tokenSold >= rounds[currentRound].amount) {
            currentRound++;
            tokenSold = 0;
            
        }
    }
    function getPurchaseInfo(address walletAddress)
        public
        view
        returns (Purchase[] memory)
    {
        return purchases[walletAddress];
    }
     function claimTokens() public {
        require(purchases[msg.sender].length > 0, "No purchases found");

        uint256 totalTokensToClaim = 0;
        for (uint256 i = 0; i < purchases[msg.sender].length; i++) {
            Purchase storage purchase = purchases[msg.sender][i];
            uint256 purchaseround = purchase.round;
            require(block.timestamp >= TGE() + rounds[purchaseround].cliff  , "Not Allowed To purchase");
            require(!purchase.claimed, "Tokens already claimed");
            totalTokensToClaim += purchase.amount;
            purchase.claimed = true;
  }
   require(
            ProjectXmeme.transfer(msg.sender, totalTokensToClaim),
            "Token transfer failed"
        );
     }
    // Function to check the Token Generation Event time
    function TGE() public view returns (uint256) {
        // Replace with your actual TGE time
        // For example, if TGE is set at 1631520000 (Unix timestamp for a specific date)
        return TGEValue; 
    }

    // Function to allow the owner to withdraw any remaining tokens after the presale
  function withdrawToken() external onlyOwner {
        uint256 balance = USDTADD.balanceOf(address(this));
        require(balance > 0, "No USDT available");
        USDTADD.transfer(owner(), balance);
    }

    function withdrawxmeme() external onlyOwner {
        uint256 balance = ProjectXmeme.balanceOf(address(this));
        require(balance > 0, "No token available");
        ProjectXmeme.transfer(owner(), balance);
    }
     function ChangeTGE(uint256 newTGE) external onlyOwner {
       TGEValue = newTGE;
    }
}