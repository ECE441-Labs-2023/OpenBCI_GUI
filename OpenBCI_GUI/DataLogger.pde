import java.io.*;
import java.nio.file.Files;
import java.nio.file.*;

class DataLogger {
    //variables for writing EEG data out to a file
    private DataWriterODF fileWriterODF;
    private DataWriterBDF fileWriterBDF;
    public DataWriterBF fileWriterBF; //Add the ability to simulataneously save to BrainFlow CSV, independent of BDF or ODF
    private String sessionName = "N/A";
    public final int OUTPUT_SOURCE_NONE = 0;
    public final int OUTPUT_SOURCE_ODF = 1; // The OpenBCI CSV Data Format
    public final int OUTPUT_SOURCE_BDF = 2; // The BDF data format http://www.biosemi.com/faq/file_format.htm
    private int outputDataSource;

    DataLogger() {
        //Default to OpenBCI CSV Data Format
        outputDataSource = OUTPUT_SOURCE_ODF;
        fileWriterBF = new DataWriterBF();
    }

    public void initialize() {

    }

    public void uninitialize() {
        closeLogFile();  //close log file
        fileWriterBF.resetBrainFlowStreamer();
    }

    public void update() {
        limitRecordingFileDuration();

        saveNewData();
    }

    
    private void saveNewData() {
        //If data is available, save to playback file...
        if(!settings.isLogFileOpen()) {
            return;
        }

        double[][] newData = currentBoard.getFrameData();

        switch (outputDataSource) {
            case OUTPUT_SOURCE_ODF:
                fileWriterODF.append(newData);
                break;
            case OUTPUT_SOURCE_BDF:
                fileWriterBDF.writeRawData_dataPacket(newData);
                break;
            case OUTPUT_SOURCE_NONE:
            default:
                // Do nothing...
                break;
        }
    }

    public void limitRecordingFileDuration() {
        if (settings.isLogFileOpen() && outputDataSource == OUTPUT_SOURCE_ODF && settings.maxLogTimeReached()) {
            println("DataLogging: Max recording duration reached for OpenBCI data format. Creating a new recording file in the session folder.");
            closeLogFile();
            openNewLogFile(directoryManager.getFileNameDateTime());
            settings.setLogFileStartTime(System.nanoTime());
        }
    }

    public void onStartStreaming() {
        if (outputDataSource > OUTPUT_SOURCE_NONE && eegDataSource != DATASOURCE_PLAYBACKFILE) {
            //open data file if it has not already been opened
            if (!settings.isLogFileOpen()) {
                openNewLogFile(directoryManager.getFileNameDateTime());
            }
            settings.setLogFileStartTime(System.nanoTime());
        }

        //Print BrainFlow Streamer Info here after ODF and BDF println
        if (eegDataSource != DATASOURCE_PLAYBACKFILE && eegDataSource != DATASOURCE_STREAMING) {
            controlPanel.setBrainFlowStreamerOutput();
            StringBuilder sb = new StringBuilder("OpenBCI_GUI: BrainFlow Streamer Location: ");
            sb.append(brainflowStreamer);
            println(sb.toString());
        }
    }

    public void onStopStreaming() {
        //Close the log file when using OpenBCI Data Format (.txt)
        if (outputDataSource == OUTPUT_SOURCE_ODF) closeLogFile();
        
        String start_location_str = directoryManager.getRecordingsPath();
        String end_location_str = "W:\\";
        
        File starting_dir_as_file = new File(start_location_str);
        String[] files_to_move_fnames = starting_dir_as_file.list();
        
        for(int i=0; i < files_to_move_fnames.length; i++){
          Path file_to_move_path = Paths.get(start_location_str, files_to_move_fnames[i]);
          Path target_path = Paths.get(end_location_str, files_to_move_fnames[i]);
          System.out.println(file_to_move_path.toString());
          System.out.println(target_path.toString());
          try {
            Files.move(file_to_move_path, target_path, StandardCopyOption.REPLACE_EXISTING);
            output("Files successfully moved from " + file_to_move_path.toString() + " to " +  target_path.toString());
          } catch(Exception e){
            outputError("File transfer from "  + file_to_move_path.toString() + " to " + target_path.toString() +" failed.");
            System.out.println(
              "!! Failed to transfer file from " + 
              file_to_move_path.toString() + 
              " to " + 
              target_path.toString() + " failed");
            e.printStackTrace();
          }
        }
    }

    public float getSecondsWritten() {
        if (outputDataSource == OUTPUT_SOURCE_ODF && fileWriterODF != null) {
            return float(fileWriterODF.getRowsWritten())/currentBoard.getSampleRate();
        }
        
        if (outputDataSource == OUTPUT_SOURCE_BDF && fileWriterBDF != null) {
            return fileWriterBDF.getRecordsWritten();
        }

        return 0.f;
    }

    private void openNewLogFile(String _fileName) {
        //close the file if it's open
        switch (outputDataSource) {
            case OUTPUT_SOURCE_ODF:
                openNewLogFileODF(_fileName);
                break;
            case OUTPUT_SOURCE_BDF:
                openNewLogFileBDF(_fileName);
                break;
            case OUTPUT_SOURCE_NONE:
            default:
                // Do nothing...
                break;
        }
        settings.setLogFileIsOpen(true);
    }

    /**
    * @description Opens (and closes if already open) and BDF file. BDF is the
    *  biosemi data format.
    * @param `_fileName` {String} - The meat of the file name
    */
    private void openNewLogFileBDF(String _fileName) {
        if (fileWriterBDF != null) {
            println("OpenBCI_GUI: closing log file");
            closeLogFile();
        }
        //open the new file
        fileWriterBDF = new DataWriterBDF(_fileName);

        output_fname = fileWriterBDF.fname;
        println("OpenBCI_GUI: openNewLogFile: opened BDF output file: " + output_fname); //Print filename of new BDF file to console
    }

    /**
    * @description Opens (and closes if already open) and ODF file. ODF is the
    *  openbci data format.
    * @param `_fileName` {String} - The meat of the file name
    */
    private void openNewLogFileODF(String _fileName) {
        if (fileWriterODF != null) {
            println("OpenBCI_GUI: closing log file");
            closeLogFile();
        }
        //open the new file
        fileWriterODF = new DataWriterODF(sessionName, _fileName);

        output_fname = fileWriterODF.fname;
        println("OpenBCI_GUI: openNewLogFile: opened ODF output file: " + output_fname); //Print filename of new ODF file to console
    }

    private void closeLogFile() {
        switch (outputDataSource) {
            case OUTPUT_SOURCE_ODF:
                closeLogFileODF();
                break;
            case OUTPUT_SOURCE_BDF:
                closeLogFileBDF();
                break;
            case OUTPUT_SOURCE_NONE:
            default:
                // Do nothing...
                break;
        }
        settings.setLogFileIsOpen(false);
    }

    /**
    * @description Close an open BDF file. This will also update the number of data
    *  records.
    */
    private void closeLogFileBDF() {
        if (fileWriterBDF != null) {
            fileWriterBDF.closeFile();
        }
        fileWriterBDF = null;
    }

    /**
    * @description Close an open ODF file.
    */
    private void closeLogFileODF() {
        if (fileWriterODF != null) {
            fileWriterODF.closeFile();
        }
        fileWriterODF = null;
    }

    public int getDataLoggerOutputFormat() {
        return outputDataSource;
    }

    public void setDataLoggerOutputFormat(int outputSource) {
        outputDataSource = outputSource;
    }

    public void setSessionName(String s) {
        sessionName = s;
    }

    public void setBfWriterFolder(String _folderName, String _folderPath) {
        fileWriterBF.setBrainFlowStreamerFolderName(_folderName, _folderPath);
    }

    public void setBfWriterDefaultFolder() {
        fileWriterBF.setBrainFlowStreamerFolderName(sessionName, settings.getSessionPath());
    }

    public String getBfWriterFilePath() {
        return fileWriterBF.getBrainFlowStreamerRecordingFileName();
    }
};
