//SPDX-License-Identifier: MIT

pragma solidity =0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Vesting.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Lanco is ERC20("Lanco", "$LANC"), Ownable {
    using SafeERC20 for IERC20;
    address public immutable presalewallet;
    address public immutable cexWallet;
    address public immutable airdropsWallet;
    address public immutable liquidityWallet;
    Vesting public immutable devVesting;
    Vesting public immutable teamVesting;
    Vesting public immutable resvrsVesting;
    Vesting public immutable marketingVesting;

    constructor(
        address _presalewallet,
        address _cexWallet,
        address _airdropsWallet,
        address _liquidityWallet,
        address _devWallet,
        address _teamWallet,
        address _resvrsWallet,
        address _marketingWallet
    ) {
        require(
            _presalewallet != address(0) ||
                _cexWallet != address(0) ||
                _airdropsWallet != address(0) ||
                _liquidityWallet != address(0) ||
                _devWallet != address(0) ||
                _teamWallet != address(0) ||
                _resvrsWallet != address(0) ||
                _marketingWallet != address(0),
            "Lanc : can not be zero address"
        );
        uint64 start = uint64(block.timestamp);
        presalewallet = _presalewallet;
        cexWallet = _cexWallet;
        airdropsWallet = _airdropsWallet;
        liquidityWallet = _liquidityWallet;
        devVesting = new Vesting(
            _devWallet,
            start,
            uint64(3 * 365 days),
            uint64(3 * 30 days)
        );

        teamVesting = new Vesting(
            _teamWallet,
            start,
            uint64(3 * 365 days),
            uint64(3 * 30 days)
        );
        resvrsVesting = new Vesting(
            _resvrsWallet,
            start,
            uint64(1 * 365 days),
            uint64(2 * 30 days)
        );
        marketingVesting = new Vesting(
            _marketingWallet,
            start,
            uint64(1 * 365 days),
            uint64(2 * 30 days)
        );

        _mint(_presalewallet, 300_000_000 * 10 ** 18);
        _mint(_cexWallet, 200_000_000 * 10 ** 18);
        _mint(_airdropsWallet, 30_000_000 * 10 ** 18);
        _mint(_liquidityWallet, 150_000_000 * 10 ** 18);
        _mint(address(devVesting), 50_000_000 * 10 ** 18);
        _mint(address(teamVesting), 20_000_000 * 10 ** 18);
        _mint(address(resvrsVesting), 100_000_000 * 10 ** 18);
        _mint(address(marketingVesting), 150_000_000 * 10 ** 18);
    }

    receive() external payable {}

    function recoverothertokens(
        address tokenAddress,
        uint256 tokenAmount
    ) public onlyOwner {
        require(
            tokenAddress != address(this),
            "cannot be same contract address"
        );
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    }

    function recovertoken(address payable destination) public onlyOwner {
        require(destination != address(0), "destination is zero address");
        destination.transfer(address(this).balance);
    }
}
