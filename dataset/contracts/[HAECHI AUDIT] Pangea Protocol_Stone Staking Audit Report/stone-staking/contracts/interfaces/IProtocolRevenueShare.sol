// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0;

interface IProtocolRevenueShareEvent {
    // @notice 리워드 수집 시 호출
    event Collect(address indexed pool, address indexed token, uint256 amount);

    // @notice 토큰을 스왑 후 분배 시 호출
    event Share(
        address indexed feeToken,
        address indexed revenueToken,
        uint256 amount,
        uint256 output,
        uint256 growthFundShare,
        uint256 daoFundShare
    );

    // @notice revenue Token 변경 시 호출
    event SetRevenueToken(address token);

    // @notice GrowthFund 변경 시 호출
    event SetGrowthFund(address fund);

    // @notice DaoFund 변경 시 호출
    event SetDaoFund(address fund);

    // @notice 최소 수익 기준 변경시 호출
    event SetMinimumRevenue(uint256 amount);

    // @notice Growth Fund Rate 변경시 호출
    event SetGrowthFundRate(address pool, uint256 rate);

    // @notice Factory Growth Fund Rate 변경시 호출
    event SetFactoryGrowthFundRate(address factory, uint256 rate);

    // @notice 브로커 verify 여부 변경 시 호출
    event VerifyBroker(address broker, bool isVerified);
}

interface IProtocolRevenueShare is IProtocolRevenueShareEvent {
    // @notice 판게아스왑의 풀들에서부터 수수료 수취 호출
    function collectByPage(uint256 start, uint256 limit) external;

    // @notice 특정 풀에서 프로토콜 수익 모으기
    function collectFrom(address pool) external;

    // @notice 풀에서 발생한 수익을 스왑 후, Growth Fund와 Dao Fund로 분배
    // @param feeToken 프로토콜에서 발생한 수익 토큰
    // @param minimumOutput 스왑할 경우, 슬리피지를 고려한 output
    // @param broker feeToken을 revenueToken으로 전환을 수행하는 컨트랙트 ( pangeaswap pool Router, swap Scanner, 1inch, ...)
    // @param data broker 컨트랙트로의 콜백 데이터
    function share(address feeToken, uint256 minimumOutput, address payable broker, bytes calldata data) external;
}
