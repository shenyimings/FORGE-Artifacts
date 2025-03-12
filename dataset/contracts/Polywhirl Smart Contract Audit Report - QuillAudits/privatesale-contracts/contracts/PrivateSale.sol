//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PrivateSale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    ERC20 public stable_coin;
    ERC20 public sale_token;

    bool public isRaiseComplete = false;

    mapping(address => bool) public influencer_whitelist;
    mapping(address => bool) public individual_whitelist;
    mapping(address => bool) public vc_whitelist;

    mapping(address => uint256) public influencer_purchased;
    mapping(address => uint256) public individual_purchased;
    mapping(address => uint256) public vc_purchased;

    mapping(address => Purchase) public purchases;

    struct Purchase {
        uint256 token_amount;
        address purchaser;
        uint256 stable_coin_amount;
        uint256 timestamp;
        string purchase_type;
        bool withdrawn;
    }

    uint256 public constant vc_tokens = 100000; // 10% (TGE emmision) of 100,000 tokens per VC
    uint256 public constant influencer_tokens = 25000; // 10% (TGE emmision) of 25,000 tokens per influencer
    uint256 public constant individual_tokens = 25000; // 10% (TGE emmision) of 25,000 tokens per participant

    uint256 public constant max_vc = 10;
    uint256 public constant max_influencer = 15;
    uint256 public constant max_individual = 25;

    uint256 public constant stable_coin_decimals = 1e6;

    uint256 public vc_purchase_count = 0;
    uint256 public influencer_purchase_count = 0;
    uint256 public individual_purchase_count = 0;

    uint256 exchange_rate_cents = 10; // $0.1
    uint256 TGE_unlock = 10; // 10% unlocked at TGE

    event addedToInfluencerWhitelist(address[] indexed accounts);
    event addedToIndividualWhitelist(address[] indexed accounts);
    event addedToVCWhitelist(address[] indexed accounts);

    event removedFromInfluencerWhitelist(address[] indexed accounts);
    event removedFromIndividualWhitelist(address[] indexed accounts);
    event removedFromVCWhitelist(address[] indexed accounts);

    event PurchaseCompleted(
        uint256 indexed token_amount,
        address indexed purchaser,
        uint256 indexed stable_coin_amount,
        uint256 timestamp,
        string purchase_type
    );

    event TokensRedeemed(
        uint256 indexed token_amount,
        address indexed purchaser,
        uint256 timestamp,
        string purchase_type
    );

    modifier raiseIncomplete() {
        require(!isRaiseComplete, "Raise is now complete");
        _;
    }

    modifier raiseComplete() {
        require(isRaiseComplete, "Raise not yet marked complete");
        _;
    }

    modifier onlyPurchased() {
        require(
            purchases[msg.sender].token_amount != 0,
            "You have not purchased the tokens"
        );
        _;
    }

    constructor(address _sale_token_address, address _stable_coin_address) {
        sale_token = ERC20(_sale_token_address);
        stable_coin = ERC20(_stable_coin_address);
    }

    function _amountInStableCoin(uint256 token_amount)
        private
        view
        returns (uint256)
    {
        return
            // converts tokens being sold into the amount of stable coin to be purchased with
            // exchnage rate specifies the rate at which each token is sold, in cents
            // hence needs to be divided by 100 to convert to US Dollars
            // Lastly adjusted for decimals of the stable coin
            token_amount.mul(exchange_rate_cents).div(100).mul(
                stable_coin_decimals
            );
    }

    function _redeemableTokens(Purchase memory purchase)
        private
        view
        returns (uint256)
    {
        // AT TGE only fixed percentage is allowed to be unlocked, and is hence calculated via the following formulka below
        // It is divided by 100 to convert in % and is adjusted for 18 decimals of the tokens
        return purchase.token_amount.mul(1e18).mul(TGE_unlock).div(100);
    }

    function whitelistInfluencer(address[] memory _influencer_addresses)
        external
        onlyOwner
    {
        require(
            _influencer_addresses.length <= 100,
            "Please whitelist maximum 100 addresses at a time"
        );
        for (uint256 i = 0; i < _influencer_addresses.length; i++) {
            require(
                _influencer_addresses[i] != address(0),
                "Zero Address given"
            );
            require(influencer_whitelist[_influencer_addresses[i]] != true);
            influencer_whitelist[_influencer_addresses[i]] = true;
        }
        emit addedToInfluencerWhitelist(_influencer_addresses);
    }

    function whitelistIndividual(address[] memory _individual_addresses)
        external
        onlyOwner
    {
        require(
            _individual_addresses.length <= 100,
            "Please whitelist maximum 100 addresses at a time"
        );
        for (uint256 i = 0; i < _individual_addresses.length; i++) {
            require(
                _individual_addresses[i] != address(0),
                "Zero Address given"
            );
            require(individual_whitelist[_individual_addresses[i]] != true);
            individual_whitelist[_individual_addresses[i]] = true;
        }
        emit addedToIndividualWhitelist(_individual_addresses);
    }

    function whitelistVC(address[] memory _vc_addresses) external onlyOwner {
        require(
            _vc_addresses.length <= 100,
            "Please whitelist maximum 100 addresses at a time"
        );
        for (uint256 i = 0; i < _vc_addresses.length; i++) {
            require(_vc_addresses[i] != address(0), "Zero Address given");
            require(vc_whitelist[_vc_addresses[i]] != true);
            vc_whitelist[_vc_addresses[i]] = true;
        }
        emit addedToVCWhitelist(_vc_addresses);
    }

    function removeWhitelistInfluencer(address[] memory _influencer_addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _influencer_addresses.length; i++) {
            require(influencer_whitelist[_influencer_addresses[i]] != false);
            influencer_whitelist[_influencer_addresses[i]] = false;
        }
        emit removedFromInfluencerWhitelist(_influencer_addresses);
    }

    function removeWhitelistIndividual(address[] memory _individual_addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _individual_addresses.length; i++) {
            require(individual_whitelist[_individual_addresses[i]] != false);
            individual_whitelist[_individual_addresses[i]] = false;
        }
        emit removedFromIndividualWhitelist(_individual_addresses);
    }

    function removeWhitelistVC(address[] memory _vc_addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _vc_addresses.length; i++) {
            require(vc_whitelist[_vc_addresses[i]] != false);
            vc_whitelist[_vc_addresses[i]] = false;
        }
        emit removedFromVCWhitelist(_vc_addresses);
    }

    function purchaseInfluencer() external raiseIncomplete {
        require(
            influencer_whitelist[msg.sender],
            "You are not whitelisted as an influencer"
        );
        require(
            influencer_purchase_count < max_influencer,
            "Influencer allocations are exhausted"
        );
        require(
            influencer_purchased[msg.sender] == 0,
            "You have already claimed your allocation"
        );
        uint256 stable_coin_amount = _amountInStableCoin(influencer_tokens);
        uint256 allowance = stable_coin.allowance(msg.sender, address(this));
        require(
            allowance >= stable_coin_amount,
            "Stable Coin Allowance lower than required. Approve More"
        );
        require(
            stable_coin.transferFrom(
                msg.sender,
                address(this),
                stable_coin_amount
            ),
            "Purchase failed"
        );

        influencer_purchase_count = influencer_purchase_count.add(1);
        influencer_purchased[msg.sender] = influencer_tokens;

        Purchase memory purchase = Purchase(
            influencer_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "Influencer",
            false
        );
        purchases[msg.sender] = purchase;

        emit PurchaseCompleted(
            influencer_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "Influencer"
        );
    }

    function purchaseIndividual() external raiseIncomplete {
        require(
            individual_whitelist[msg.sender],
            "You are not whitelisted as an individual"
        );
        require(
            individual_purchase_count < max_individual,
            "Individual allocations are exhausted"
        );
        require(
            individual_purchased[msg.sender] == 0,
            "You have already claimed your allocation"
        );
        uint256 stable_coin_amount = _amountInStableCoin(individual_tokens);
        uint256 allowance = stable_coin.allowance(msg.sender, address(this));
        require(
            allowance >= stable_coin_amount,
            "Stable Coin Allowance lower than required. Approve More"
        );

        require(
            stable_coin.transferFrom(
                msg.sender,
                address(this),
                stable_coin_amount
            ),
            "Purchase failed"
        );

        individual_purchase_count = individual_purchase_count.add(1);
        individual_purchased[msg.sender] = individual_tokens;

        Purchase memory purchase = Purchase(
            individual_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "Individual",
            false
        );
        purchases[msg.sender] = purchase;

        emit PurchaseCompleted(
            individual_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "Individual"
        );
    }

    function purchaseVc() external raiseIncomplete {
        require(vc_whitelist[msg.sender], "You are not whitelisted as an vc");
        require(vc_purchase_count < max_vc, "Vc allocations are exhausted");
        require(
            vc_purchased[msg.sender] == 0,
            "You have already claimed your allocation"
        );
        uint256 stable_coin_amount = _amountInStableCoin(vc_tokens);
        uint256 allowance = stable_coin.allowance(msg.sender, address(this));
        require(
            allowance >= stable_coin_amount,
            "Stable Coin Allowance lower than required. Approve More"
        );

        require(
            stable_coin.transferFrom(
                msg.sender,
                address(this),
                stable_coin_amount
            ),
            "Purchase failed"
        );

        vc_purchase_count = vc_purchase_count.add(1);
        vc_purchased[msg.sender] = vc_tokens;

        Purchase memory purchase = Purchase(
            vc_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "VC",
            false
        );
        purchases[msg.sender] = purchase;

        emit PurchaseCompleted(
            vc_tokens,
            msg.sender,
            stable_coin_amount,
            block.timestamp,
            "VC"
        );
    }

    function redeemTokens() external onlyPurchased raiseComplete nonReentrant {
        Purchase memory purchase = purchases[msg.sender];
        require(!purchase.withdrawn, "Address has already redeemed tokens");
        uint256 tokens_to_redeem = _redeemableTokens(purchase);
        require(
            sale_token.balanceOf(address(this)) >= tokens_to_redeem,
            "Insufficient redeemable tokens in contract"
        );
        purchase.withdrawn = true;
        purchases[msg.sender] = purchase;
        require(
            sale_token.transfer(
                purchase.purchaser,
                tokens_to_redeem // convert to percent
            ),
            "Redeem transfer failed"
        );
        emit TokensRedeemed(
            purchase.token_amount,
            purchase.purchaser,
            block.timestamp,
            purchase.purchase_type
        );
    }

    function markRaiseComplete() external onlyOwner {
        isRaiseComplete = true;
    }

    function markRaiseInComplete() external onlyOwner {
        isRaiseComplete = false;
    }

    function withdrawFunds() external onlyOwner {
        // Withdraw all raised funds to owner
        stable_coin.transfer(msg.sender, stable_coin.balanceOf(address(this)));
    }

    function withdrawUnsoldTokens() external onlyOwner raiseComplete {
        // Withdraw unsold $WHIRL
        uint256 unsoldTokens = sale_token.balanceOf(address(this));
        if (unsoldTokens > 0) {
            require(
                sale_token.transfer(msg.sender, unsoldTokens),
                "Token withdraw failed"
            );
        }
    }

    function removeOtherERC20Tokens(address _tokenAddress, address _to)
        external
        onlyOwner
    {
        require(
            _tokenAddress != address(sale_token),
            "Token Address has to be diff than $WHIRL token"
        );
        ERC20 erc20Token = ERC20(_tokenAddress);
        require(
            erc20Token.transfer(_to, erc20Token.balanceOf(address(this))),
            "ERC20 Token transfer failed"
        );
    }
}
