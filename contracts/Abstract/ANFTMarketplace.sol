// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interface/INFTMarketplace.sol";
import "../library/AmountTransfer.sol";
    /***
        @notice abstract contract ANFTMarketplace  .
        @param owner  The address of the token holder
        @return        The account's balance of the Token type requested
     */
abstract contract ANFTMarketplace is INFTMarketplace {
    using SafeMath for uint256;

    uint256 public makerFee;
    address public owner;

    mapping(address => mapping(uint256 => uint256)) indexFixedSaleNFT;
    mapping(address => mapping(uint256 => uint256)) indexAuctionSaleNFT;
    mapping(address => mapping(uint256 => Auction)) nftContractAuctionSale;
    mapping(address => mapping(uint256 => FixedSale)) nftContractFixedSale;
    mapping(address => mapping(uint256 => uint256)) public nftSaleStatus;
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public userBidPriceOnNFT;

    SaleInfo[] fixedSaleNFT;
    SaleInfo[] auctionSaleNFT;

    modifier buyPriceMeetSalePrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _buyPrice
    ) {
        require(
            _buyPrice >=
                nftContractFixedSale[_nftContractAddress][_tokenId].salePrice,
            "buy Price not enough"
        );
        _;
    }

    modifier isAuctionOngoing(address _nftContractAddress, uint256 _tokenId) {
        require(
            block.timestamp <
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .auctionEnd,
            "Auction end"
        );
        _;
    }

    modifier isAuctionResetByOwner(
        address _nftContractAddress,
        uint256 _tokenId
    ) {
        require(
            msg.sender ==
                nftContractAuctionSale[_nftContractAddress][_tokenId].nftSeller,
            "not nft owner"
        );
        _;
    }

    modifier isAuctionOver(address _nftContractAddress, uint256 _tokenId) {
        require(
            block.timestamp >
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .auctionEnd,
            "Auction not end"
        );
        _;
    }

    modifier isbidNotMakeTillNow(
        address _nftContractAddress,
        uint256 _tokenId
    ) {
        require(
            address(0) ==
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .nftHighestBidder,
            "bid make"
        );
        _;
    }

    modifier isContractApprove(address _nftContractAddress, uint256 _tokenId) {
        require(
            IERC721(_nftContractAddress).isApprovedForAll(
                msg.sender,
                address(this)
            ),
            "Nft not approved to contract"
        );
        _;
    }

    modifier isNftAlreadyInSale(address _nftContractAddress, uint256 _tokenId) {
        require(
            nftSaleStatus[_nftContractAddress][_tokenId] == 0,
            "Nft already in sale"
        );
        _;
    }

    modifier isNftInAuctionSale(address _nftContractAddress, uint256 _tokenId) {
        require(
            nftSaleStatus[_nftContractAddress][_tokenId] == 2,
            "Nft not in auction sale"
        );
        _;
    }

    modifier isNftInFixedSale(address _nftContractAddress, uint256 _tokenId) {
        require(
            nftSaleStatus[_nftContractAddress][_tokenId] == 1,
            "Nft not in fixed sale"
        );
        _;
    }

    modifier islatestBidGreaterPreviousOne(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _bidPrice,
        uint256 _bidPrice1
    ) {
        if (
            nftContractAuctionSale[_nftContractAddress][_tokenId].erc20 ==
            address(0)
        ) {
            require(
                _bidPrice >
                    nftContractAuctionSale[_nftContractAddress][_tokenId]
                        .nftHighestBid,
                "Bid Greater than Previous Bid"
            );
        } else {
            require(
                _bidPrice1 >
                    nftContractAuctionSale[_nftContractAddress][_tokenId]
                        .nftHighestBid,
                "Bid Greater than Previous Bid"
            );
        }

        _;
    }

    modifier isSaleStartByOwner(address _nftContractAddress, uint256 _tokenId) {
        require(
            msg.sender == IERC721(_nftContractAddress).ownerOf(_tokenId),
            "You are not nft owner"
        );
        _;
    }

    modifier isSaleResetByOwner(address _nftContractAddress, uint256 _tokenId) {
        require(
            msg.sender ==
                nftContractFixedSale[_nftContractAddress][_tokenId].nftSeller,
            "You are not nft owner"
        );
        _;
    }

    modifier isUpdatedBidGreaterPreviousOne(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _updateBidPrice,
        uint256 _updateBidPrice1
    ) {
        uint256 _finalBidPrice;
        if (
            nftContractAuctionSale[_nftContractAddress][_tokenId].erc20 ==
            address(0)
        ) {
            _finalBidPrice = userBidPriceOnNFT[_nftContractAddress][_tokenId][
                msg.sender
            ].add(_updateBidPrice);
        } else {
            _finalBidPrice = userBidPriceOnNFT[_nftContractAddress][_tokenId][
                msg.sender
            ].add(_updateBidPrice1);
        }
        require(
            _finalBidPrice >
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .nftHighestBid,
            "Bid Greater than Previous Bid"
        );
        _;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not a owner");
        _;
    }

    modifier priceGreaterThanZero(uint256 _price) {
        require(_price > 0, "Price cannot be 0");
        _;
    }
     /**
        @notice function _isTokenOrCoin  .
        its a function is to check wheather it is erc2o token or blockchain coin
        accordingly it will do its operations on blockchain  
     */

    function _isTokenOrCoin(
        address _royaltyReciever,
        address _nftSeller,
        address _erc20,
        uint256 _buyAmount,
        uint256 _royalty,
        bool auction
    ) internal {
        uint256 taxAmount = (_buyAmount * makerFee) / uint256(100);
        uint256 royalty = (_buyAmount * _royalty) / uint256(100);

        uint256 userAmount = _buyAmount - (taxAmount + royalty);

        if (_erc20 != address(0)) {
            if (auction) {
                IERC20(_erc20).transfer(_nftSeller, userAmount);
                IERC20(_erc20).transfer(owner, taxAmount);
                IERC20(_erc20).transfer(_royaltyReciever, royalty);
            } else {
                AmountTransfer.tokenAmountTransfer(
                    msg.sender,
                    _nftSeller,
                    _erc20,
                    userAmount
                );
                AmountTransfer.tokenAmountTransfer(msg.sender,owner, _erc20, taxAmount);
                AmountTransfer.tokenAmountTransfer(
                    msg.sender,
                    _royaltyReciever,
                    _erc20,
                    royalty
                );
            }
        } else {
            AmountTransfer.nativeAmountTransfer(_nftSeller, userAmount);
            AmountTransfer.nativeAmountTransfer(owner, taxAmount);
            AmountTransfer.nativeAmountTransfer(_royaltyReciever, royalty);
        }
    }
     /**
        @notice function _storedNftAuctionDetails  .
        its a function is to store details of nft 
     */

    function _storedNftAuctionDetails(
        address _nftContractAddress,
        address _erc20,
        address _royaltyReciever,
        uint256 _royalty,
        uint256 _tokenId,
        uint256 _auctionStart,
        uint256 _auctionEnd,
        uint256 _minPrice
    ) internal {
        nftContractAuctionSale[_nftContractAddress][_tokenId] = Auction(
            _auctionStart,
            _auctionEnd,
            _minPrice,
            _minPrice,
            _royalty,
            address(0),
            msg.sender,
            _erc20,
            _royaltyReciever
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 2;

        IERC721(_nftContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        indexAuctionSaleNFT[_nftContractAddress][_tokenId] = auctionSaleNFT
            .length;
        auctionSaleNFT.push(SaleInfo(_nftContractAddress, _tokenId));

        emit NftAuctionSale(
            _nftContractAddress,
            msg.sender,
            _erc20,
            _tokenId,
            _auctionStart,
            _auctionEnd,
            _minPrice
        );
    }

    function _transferNftAndPaySeller(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _bidPrice,
        address _nftBuyer
    ) internal {
        IERC721(_nftContractAddress).safeTransferFrom(
            address(this),
            _nftBuyer,
            _tokenId
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 0;

        _isTokenOrCoin(
            nftContractAuctionSale[_nftContractAddress][_tokenId]
                .royaltyReciever,
            nftContractAuctionSale[_nftContractAddress][_tokenId].nftSeller,
            nftContractAuctionSale[_nftContractAddress][_tokenId].erc20,
            _bidPrice,
            nftContractAuctionSale[_nftContractAddress][_tokenId].royalty,
            true
        );
    }
}
