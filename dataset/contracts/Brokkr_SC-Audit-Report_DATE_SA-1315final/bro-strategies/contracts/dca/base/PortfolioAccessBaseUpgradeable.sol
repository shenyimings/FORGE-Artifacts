// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract PortfolioAccessBaseUpgradeable is OwnableUpgradeable {
    error PortfolioAlreadyWhitelisted();
    error PortfolioNotFound();

    event PortfolioAdded(address indexed newPortfolio);
    event PortfolioRemoved(address indexed removedPortfolio);

    address[] public whitelistedPortfolios;

    // solhint-disable-next-line
    function __PortfolioAccessBaseUpgradeable_init() internal onlyInitializing {
        __Ownable_init();
    }

    modifier onlyPortfolio() {
        bool authorized;
        for (uint256 i = 0; i < whitelistedPortfolios.length; i++) {
            if (whitelistedPortfolios[i] == _msgSender()) {
                authorized = true;
            }
        }

        require(authorized, "Unauthorized");
        _;
    }

    function addPortfolio(address newPortfolio) public virtual onlyOwner {
        for (uint256 i = 0; i < whitelistedPortfolios.length; i++) {
            if (whitelistedPortfolios[i] == newPortfolio) {
                revert PortfolioAlreadyWhitelisted();
            }
        }

        whitelistedPortfolios.push(newPortfolio);
        emit PortfolioAdded(newPortfolio);
    }

    function removePortfolio(address portfolio) public virtual onlyOwner {
        for (uint256 i = 0; i < whitelistedPortfolios.length; i++) {
            if (whitelistedPortfolios[i] == portfolio) {
                whitelistedPortfolios[i] = whitelistedPortfolios[
                    whitelistedPortfolios.length - 1
                ];
                whitelistedPortfolios.pop();

                emit PortfolioRemoved(portfolio);
                return;
            }
        }

        revert PortfolioNotFound();
    }
}
