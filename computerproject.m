clc;clear;
%% USER INPUT
userinput=input('ENTER USB OR UART ,any other input is an error ! ','s');

InputFileId=fopen('inputdata.txt');
  %% USB

if ismember(userinput,{'USB'})
    %% USBREAD
    
    config=textread('config_USB.txt','%s');
    
    InputDataDecimal=fread(InputFileId);
    InputDataBin=dec2bin(InputDataDecimal,8);
    InputBinFlipped=fliplr(InputDataBin);
    IntputBinFlippedTransposed=InputBinFlipped';
    DataChar=reshape(IntputBinFlippedTransposed,[],1);
    DataStream=str2num(DataChar);
    partofDataStream=DataStream(1:256,1);
    
   
    %% INPUTDATA
    time=0;
    overhead=0;
    
    for i=1:96
        
       
         
        DataStream=[DataStream;partofDataStream];
        
        SizeofDataStreaam=size(DataStream,1);
        
        if(mod(SizeofDataStreaam,1024))==0
            DataPacket=reshape(DataStream,1024,[]);
            NumberOfPackets=floor(SizeofDataStreaam/1024);
        else
            remainder=rem(SizeofDataStreaam,1024);
            NumberOfPacketsold=floor(SizeofDataStreaam/1024);
            NumberOfPackets=NumberOfPacketsold+1 ;
            paddrowsnumber=NumberOfPackets*1024-SizeofDataStreaam;
            Datastreampad=padarray(DataStream,[paddrowsnumber 0 ],0,'post');
            DataPacket=reshape(Datastreampad,1024,NumberOfPackets);
            
            
        end
        
        
        
        
        
       
        %% SYNC
     
        SYNCSizeCELL=config(2,1);
        SYNCSizeChar=cell2mat(SYNCSizeCELL);
        SYNCSize=str2num(SYNCSizeChar);
        %gettting the syncronization size in the file given and converting it to
        %a numiracal value
        SYNCNotTransposed=[zeros(SYNCSize-1,1)' 1] ;
        SYNC=SYNCNotTransposed';
        %getting the sync pattern in a one coloumn form
        SYNCRepeated=repmat(SYNC,1,NumberOfPackets);
        %% PID
  
        
        PIDSizeCELL=config(3,1);
        PIDSizeChar=cell2mat(PIDSizeCELL);
        PIDSize=str2num(PIDSizeChar);
        %gettting the packet size in the file given and converting it to
        %a numiracal value
        pidnum=rem(1:NumberOfPackets,16);
        PIDArrayactual=decimalToBinaryVector(pidnum,4)';
        PIDarrayinverted=~PIDArrayactual;
        PIDArray=[PIDArrayactual;PIDarrayinverted];
        
        %% CRCDATA
        PolynomialData=[1,1,0,0,0,0,0,0,0,0,0,0,0,1,0,1];
        %polynoial needed for the crc generator this value is a standard value for
        %data
        InitialConditionsData=ones(1,15);
        %intial conditions for shift registers of crc generation for data
        H1=comm.CRCGenerator('Polynomial',PolynomialData,'InitialConditions',InitialConditionsData);
        %creating an object for CRC generation of data
        for i=1:NumberOfPackets
            DATAandCRC(:,i)=step(H1,DataPacket(:,i));
        end
        %the crc for the data is created and added at the end of the data matrix
        for i=1:NumberOfPackets
            CRCDataOnly(:,i)=DATAandCRC(1025:1039,i);
        end
        
        %% CRCADRESS
        
        AddressAsText=config(4,1);
        AdressAsSingleElement=cell2mat(AddressAsText');
        AdressArrayOfChar=reshape(AdressAsSingleElement,[],1);
        Address=str2num(AdressArrayOfChar);
        AddressRepeated=repmat(Address,1,NumberOfPackets);
        %the fourth line of the adress was extracted from the cell and then
        %reshaped into an array of charachters then into a numerical array with the
        %LSB being the first element
        
        PolynomialAdress=[1,0,0,1,0,1];
        %polynoial needed for the crc generator this value is a standard value for
        %address
        InitialConditionsAdress=ones(1,5);
        %intial conditions for shift registers of crc generation for address
        H2=comm.CRCGenerator('Polynomial',PolynomialAdress,'InitialConditions',InitialConditionsAdress);
        %creating an object for CRC generation of address
        AdressandCRCAddress=step(H2,Address);
        %the crc for the address is created and added at the end of the address matrix
        CRCAddressOnly=AdressandCRCAddress(12:16,1);
        %this matrix has the crc of address only
        CRCAdsressRepeated=repmat(CRCAddressOnly,1,NumberOfPackets);
        
        %% CONCAT
        
        DataFrame=[SYNCRepeated;PIDArray;AddressRepeated;DataPacket;....
            CRCAdsressRepeated;CRCDataOnly];
        sizedataframe=length(reshape(DataFrame,[],1));
        
        %% BITSTUFF
        
        for i=1:NumberOfPackets
            
            DataFrameStuffed{i} =num2cell((regexprep(char(DataFrame(:,i)'+ '0' ), '111111', '1111110') - '0')') ;
        end
        
        %this function is used originally for strings or characters so we can do
        % a manipulation by adding 48 or char '0' to chnage the numeric values to character
        %then use this function that replaces the given '111111' block if found with
        % '1111110' but this is all done in charachter format so returning back to
        %numeric is done by subtracting zero char value 48 or char zero '0'
        %for checking u can use the trial matrix with six zeros
        %trial=[1,1,1,1,1,1,0,0,0];
        %tstuff=regexprep(char(trial+ '0' ), '111111', '1111110') - '0' ;
        
      
        %% NRZI
        
    len = cellfun(@length, DataFrameStuffed);
    
    for i=1:NumberOfPackets
        nrzi{i}=zeros(len(i),1);
        for j= 2:length(nrzi{i}+1)
            if cell2mat(DataFrameStuffed{1,i}(j))== 0
                nrzi{1,i}(j)=~nrzi{1,i}(j-1) ;
            elseif cell2mat(DataFrameStuffed{1,i}(j))== 1
                nrzi{1,i}(j)= nrzi{1,i}(j-1);
            end
        end
        nrzi{1,i}=[1;nrzi{1,i};0;0];
       
    end
    len2 = cellfun(@length, nrzi);
sizeofnrzi = sum( len2 , 2 );
packet1plot=cell2mat(nrzi(1,1));
packet2plot=cell2mat(nrzi(1,2));
twopackets2plot=[packet1plot;packet2plot];

Smallpacket=packet1plot(1:135,1);
    %% REQ
        
BitDurationText=config(6,1);
BitDurationChar=cell2mat(BitDurationText');
BitDurationUSB=str2num(BitDurationChar);


overheadcount=50;
TimeTotalUSB=(sizeofnrzi)*BitDurationUSB;
EffiecenyUSB=SizeofDataStreaam/(sizeofnrzi)*100 ;
OverheadPercentageUSB=((sizeofnrzi-length(DataStream)))/sizeofnrzi*100 ;
    
    %% PLOTS
    
    packet1plot=cell2mat(nrzi(1,1));
    packet2plot=cell2mat(nrzi(1,2));
    twopackets2plot=[packet1plot;packet2plot];
    
    Smallpacket=packet1plot(1:135,1);
    
   % TimeTotalUSB1=sizeofnrzi*0.1;
    %EffiecenyUSB1=SizeofDataStreaam/(sizeofnrzi)*100 ;
    %OverheadPercentageUSB1= ;
    
    TZ(i,1)=TimeTotalUSB;
    oz(i,1)=OverheadPercentageUSB;
    time=[time;TZ(i,1)] ;
    overhead=[ overhead;oz(i,1)] ;




    end
    
    
    %% PLOTSS
    

%disp('TimeTotalUSB in sec with a bit duration of 0.1S is');
%disp(TimeTotalUSB1);
%disp('EffiecenyUSB in sec with a bit duration of 0.1S is');
%disp(EffiecenyUSB1);
%disp('OverheadPercentageUSB in sec with a bit duration of 0.1S is');
%disp(OverheadPercentageUSB1);

figure();
stairs(twopackets2plot);
title(' TWo packets of the USB for bit duration of 0.1 ');
figure();
stairs(Smallpacket);
title(' 1/8 packet of the USB for bit duration of 0.1 ');


figure()
plot(time(2:(i),1));
title('time with file size');
figure()
plot(overhead(2:(i),1));
title('overhead with file size  ');

    
elseif ismember(userinput,{'UART'})
    
    
    
    %% uart
    
    %%  input user
    
    configUART=textread('config_UART.txt','%s');
    
    databits=input('what is the number of data bits per packet (7) or (8) ?  ','s');
    if  ~ismember(databits,{'7','8'})
        error ('INVALID number of data bits !');
    end
    
    stopbits=input('what is the number of stop bits (1) or (2) ','s');
    if  ~ismember(stopbits,{'1','2'})
        error ('INVALID number of stop bits !');
    end
    
    paritytype=input('what is the parity used (even) or (odd) or (non)  ','s');
    if  ~ismember(paritytype,{'even','odd','non'})
        error ('INVALID parity entered!');
    end
    
    
    
    BitdurationUARTtext=configUART(2,1);
    BitdurationUARTmat=cell2mat(BitdurationUARTtext);
    BitdurationUART=str2num(BitdurationUARTmat);
    %% read file
    
    
    
    InputDataDecimal=fread(InputFileId);
    InputDataBin2=dec2bin(InputDataDecimal,str2num(databits));
    InputBinFlipped2=fliplr(InputDataBin2);
    IntputBinFlippedTransposed2=InputBinFlipped2';
    DataChar2=reshape(IntputBinFlippedTransposed2,[],1);
    
   
        
    DataStream2=str2num(DataChar2);
    partdatastream2=DataStream2(1:135,1);
    
    
    
      time=0;
  overhead=0;
  
    for count=1:30
    DataStream2=[DataStream2;partdatastream2];
       SizeofDataStreaam2=length(DataStream2);

    %%%%%%%%
      
        if(mod(SizeofDataStreaam2,str2num(databits)))==0
            DataPacket=reshape(DataStream2,str2num(databits),[]);
            sizeofdatapacket2=size(DataPacket,2);
            NumberOfwords=floor(SizeofDataStreaam2/str2num(databits));
        else
            remainder=rem(SizeofDataStreaam2,str2num(databits));
            NumberOfwordsold=floor(SizeofDataStreaam2/str2num(databits));
            NumberOfwords=NumberOfwordsold+1 ;
            paddrowsnumber=NumberOfwords*str2num(databits)-SizeofDataStreaam2;
            Datastreampad=padarray(DataStream2,[paddrowsnumber 0 ],0,'post');
            DataPacket=reshape(Datastreampad,str2num(databits),[]);
            sizeofdatapacket2=size(DataPacket,2);
        end
    %%%%%%%%%
    startbit=0;
    startbitrepeated=repmat(startbit,1,sizeofdatapacket2);
    
    sizeofdatapureuart=length(DataStream2);
    numberofstopbitsUART=str2num(stopbits);
    
    
    if numberofstopbitsUART==1
        stopbitsUART=1;
    end
    if numberofstopbitsUART==2
        stopbitsUART=[1;1];
    end
    stopbitsUARTrepeated=repmat(stopbitsUART,1,sizeofdatapacket2);
    
    newsizewithparityspace=str2num(databits)+1;

    %% check parity


if  ismember(paritytype,{'odd'})
    datapaddedUART=padarray(DataPacket,[1 0],0,'post');
    for i=1:sizeofdatapacket2
        for j=1:str2num(databits)
            datapaddedUART(newsizewithparityspace,i)=xor(datapaddedUART(newsizewithparityspace,i),datapaddedUART(j,i));
            
        end
        
    end
    
    for k= 1:sizeofdatapacket2
        datapaddedUART(newsizewithparityspace,k)=not(datapaddedUART(newsizewithparityspace,k));
    end
    
    
    dataframe=[startbitrepeated;datapaddedUART;stopbitsUARTrepeated];
end
if  ismember(paritytype,{'even'})
    datapaddedUART=padarray(DataPacket,[1 0],0,'post');
    
    for i=1:sizeofdatapacket2
        for j=1:str2num(databits)
            datapaddedUART(newsizewithparityspace,i)=xor(datapaddedUART(newsizewithparityspace,i),datapaddedUART(j,i));
            
        end
    end
    
    
    
    
    dataframe=[startbitrepeated;datapaddedUART;stopbitsUARTrepeated];
end

if  ismember(paritytype,{'non'})
    dataframe=[startbitrepeated;DataPacket;stopbitsUARTrepeated];
end
%% displayresults

dataframreshaped=reshape(dataframe,[],1);
sizeofdataframe=length(dataframreshaped);
timeuart=BitdurationUART*sizeofdataframe;
overheadcount=2+numberofstopbitsUART;
effeicencyuart=(sizeofdatapureuart/sizeofdataframe)*100 ;
overheaduart=(overheadcount*NumberOfwords)/sizeofdataframe*100;

    TZ(count,1)=timeuart;
    oz(count,1)=overheaduart;
    time=[time;TZ(count,1)] ;
    overhead=[ overhead;oz(count,1)] ;
    end
    
 
%disp('TimeUART in sec with a bit duration of 0.1S is');
%disp(timeuart);
%disp('EffiecenyUART in sec with a bit duration of 0.1S is');
%disp(effeicencyuart);
%disp('OverheadPercentageUART in sec with a bit duration of 0.1S is');
%disp(overhead);

word1plot=(dataframe(1:size(dataframe,1),1));
word2plot=(dataframe(1:size(dataframe,1),2));
twowords2plot=[word1plot;word2plot];

figure();
stairs(twowords2plot);
tplot=time(2:(count),1);
overheadplot=overhead(2:(count),1);
figure()
plot(tplot);
title('time with file size');
figure()
plot(overheadplot);
title('overhead with file size  ');


    
elseif ~ismember(userinput,{'USB','UART'})
    %% not uart
    error ('INVALID SERIAL COMMUNICATION PROTOCOL !');
    end
    
    
    