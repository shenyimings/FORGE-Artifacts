// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MarshaToken is ERC20 {
    // 8 billion tokens in wei
    uint256 public constant INITIAL_SUPPLY = 8_000_000_000 * 10 ** 18;
    uint256 public constant ANNUAL_BURN_RATE = 3; // 3% annual burn rate

    uint256 public lastBurnTimestamp;
    uint256 public timeOfContractCreation;

    address public community;
    address public charity;
    address public foundation;
    address public development;
    address public marketing;
    address public investors;
    address public legal;
    address public expansion;

    uint256 halfCommunityInitialTokens;

    constructor(
        address _community,
        address _charity,
        address _foundation,
        address _development,
        address _marketing,
        address _investors,
        address _legal,
        address _expansion
    ) ERC20("MARSHA+", "MSA") {
        community = _community;
        charity = _charity;
        foundation = _foundation;
        development = _development;
        marketing = _marketing;
        investors = _investors;
        legal = _legal;
        expansion = _expansion;

        lastBurnTimestamp = block.timestamp;
        timeOfContractCreation = block.timestamp;

        _mint(address(this), INITIAL_SUPPLY);

        // community 35% all tokens are free
        _transfer(address(this), community, ((INITIAL_SUPPLY * 35) / 100));
        halfCommunityInitialTokens = balanceOf(community) / 2;
        // Charity: 25% (20% locked, 5% free)
        _transfer(address(this), charity, ((INITIAL_SUPPLY * 5) / 100));
        // Foundation: 10% (5% locked, 5% free)
        _transfer(address(this), foundation, ((INITIAL_SUPPLY * 5) / 100));
        // Development: 10% (5% free, 5% locked)
        _transfer(address(this), development, ((INITIAL_SUPPLY * 5) / 100));
        // Marketing: 8% (5% free, 3% locked)
        _transfer(address(this), marketing, ((INITIAL_SUPPLY * 5) / 100));
        // Investors: 5% (free)
        _transfer(address(this), investors, ((INITIAL_SUPPLY * 5) / 100));
        // Legal: 5% (2.5% free, 2.5% locked)
        _transfer(address(this), legal, ((INITIAL_SUPPLY * 25) / 1000));
        // Expansion: 2% (1% free, 1% locked)
        _transfer(address(this), expansion, ((INITIAL_SUPPLY * 1) / 100));
    }

    // reward tokens for team after 3 years of lounch contract
    function teamRewardAfter3Years() internal {
        if (block.timestamp >= timeOfContractCreation + 1095 days) {
            _transfer(address(this), charity, ((INITIAL_SUPPLY * 20) / 100));

            _transfer(address(this), foundation, ((INITIAL_SUPPLY * 5) / 100));

            _transfer(address(this), development, ((INITIAL_SUPPLY * 5) / 100));

            _transfer(address(this), marketing, ((INITIAL_SUPPLY * 3) / 100));

            _transfer(address(this), legal, ((INITIAL_SUPPLY * 25) / 1000));

            _transfer(address(this), expansion, ((INITIAL_SUPPLY * 1) / 100));
        }
    }

    // Function to burn a percentage of total supply annually if needed
    function burnIfNeeded() internal {
        if (block.timestamp >= lastBurnTimestamp + 365 days) {
            uint256 totalSupplyBeforeBurn = totalSupply();
            uint256 tokensToBurn = (totalSupplyBeforeBurn * ANNUAL_BURN_RATE) /
                100;
            // stop burning if burned more than half of cummunity
            if (balanceOf(community) > halfCommunityInitialTokens) {
                _burn(community, tokensToBurn);
            }
            lastBurnTimestamp = block.timestamp;
        }
    }

    // Override the ERC20 transfer function to perform burn check
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        burnIfNeeded();
        teamRewardAfter3Years();
        super.transfer(recipient, amount);
        return true;
    }

    // Override the ERC20 transferFrom function to perform burn check
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        burnIfNeeded();
        teamRewardAfter3Years();
        super.transferFrom(sender, recipient, amount);
        return true;
    }
}
