// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

contract TokenVault is ERC20Upgradeable, ERC721HolderUpgradeable {
    address public token;
    uint256 public id;

    uint256 public aunctionLength;
    uint256 public aunctionEnd;
    uint256 public livePrice;

    address payable public winning;

    uint256 public constant RESERVE_PRICE = 0.08 ether;
    uint256 public constant MIN_VOTE_PERCENTAGE = 250; // 25%
    uint256 public constant MIN_BID_INCREASE = 50; // 5%

    enum State {
        inactive,
        live,
        ended,
        redeemed
    }

    State public aunctionState;

    address public curator;
    uint256 public fee;

    uint256 public votingTokens;
    // @notice a mapping of users to their desired token price
    mapping(address => uint256) public userPrices;

    function initialize(
        address _curator,
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address _token,
        uint256 _id
    ) external {
        __ERC20_init(_name, _symbol);
        __ERC721Holder_init();
        token = _token;
        id = _id;
        _mint(_curator, _supply);
    }

    // @notice kick off an auction. Must send ReservePrice in ETH
    function start() external payable {
        require(aunctionState == State.inactive, "sale is not active");
        require(
            msg.value > RESERVE_PRICE,
            "start: not enough ether to start an aunction"
        );
        require(
            votingTokens >= MIN_VOTE_PERCENTAGE,
            "start: not enough voters"
        );

        aunctionEnd = block.timestamp + aunctionLength;
        aunctionState = State.live;
        livePrice = msg.value;
        winning = payable(msg.sender);
    }

    // @notice an external function to place bid on the nft
    function bid() external payable {
        require(aunctionState == State.live, "aunction is not live");
        uint256 increaseBy = MIN_BID_INCREASE + 1000;
        require(msg.value * 1000 >= livePrice * increaseBy, "too low bid");
        require(block.timestamp < aunctionEnd, "bid aunction ended");

        if (aunctionEnd - block.timestamp < 15 minutes) {
            aunctionEnd += 15 minutes;
        }

        _sendETH(winning, livePrice);
        livePrice = msg.value;
        winning = payable(msg.sender);
    }

    // @notice an external function to end the aunction after timer has run out
    function end() external {
        require(aunctionState == State.live, "aunction has already closed");
        require(block.timestamp >= aunctionEnd, "end: aunction live");

        IERC721(token).transferFrom(address(this), winning, id);
        aunctionState = State.ended;
    }

    // @notice an external function to redeem nft by burning all tokens
    function redeem() external {
        require(aunctionState == State.inactive, "no redeem");
        _burn(msg.sender, totalSupply());

        IERC721(token).transferFrom(address(this), msg.sender, id);
        aunctionState = State.redeemed;
    }

    // @notice an external function to burn your claimed ownership or token
    function cash() external {
        require(aunctionState == State.ended, "aunction is not ended yet");
        uint256 bal = balanceOf(msg.sender);
        require(bal > 0, "zero token balance");
        uint256 share = (bal * address(this).balance) / totalSupply();
        _burn(msg.sender, bal);

        _sendETH(payable(msg.sender), share);
    }

    function _sendETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value, gas: 30000}("");
        require(success, "Eth transfer failed");
    }
}
