import sys
import os

class SubtitleWriter:
    """ Writer module for parsers
    """
    def __init__( self, font, fontsize, fillcolor, outlinecolor, outlinewidth,
                  resolution ):
        """ Initializer
        
            Parameters:
                font: Name of the font used for subtitles
                fontsize: Size of the font used for subtitles
                fillcolor: Color to fill the text with
                outlinecolor: Color for the outline of the text
                outlinewidth: Width of the texts' outline
                resolution: Resolution of the movie
        """
        # Template for magick command
        self.magick = (
            f"magick -size {resolution} xc:\"#808080\" " +
            "-gravity south " +
            f"-fill {fillcolor} -stroke {outlinecolor} -strokewidth 1.2 " +
            f"-font {font} " +
            f"-pointsize {fontsize} -gravity south "
        )
        self.subtext_filename = "-annotate 0 '%(subtext)s' '%(filename)s'"

        # Template for xml subtitle item
        self.spunode = (
            "\t<spu transparent=\"#808080\" start=\"%(starttime)s\" end=\"%(endtime)s\" " +
            "image=\"%(filename)s\" />\n"
        )
        
    def open( self, outfilename ):
        """ Opens a file for xml output

            Parameters:
                outfilename: Name for output file or - for stdout

            Returns:
                True if outputfile was opened and written succesfully,
                False otherwise
        """
        if outfilename == "-":
            self.outfile = sys.stdout
        else:
            try:
                self.outfile = open( outfilename, "w" )
            except:
                return False
        try:
            self.outfile.write( "<subpictures>\n" )
            self.outfile.write( "    <stream>\n" )
        except:
            if self.outfile != sys.stdout:
                self.outfile.close()
            return False
        return True

    def write( self, number, starttime, endtime, text,
               filename="subtitle_" ):
        """ Writer function that parsers should call
    
            Parameters:
              number: Running number for the subtitle
              starttime, endtime: start and end time of the subtitle
              text: subtitle's text
              filename: filename for subtitle image

            Returns:
                True if subtitle was written succesfully,
                False otherwise
        """
        # Fill in the templates
        pngfilename = f"{os.path.dirname(os.path.abspath(self.outfile.name))}/{filename}{number}"
        command = self.magick + self.subtext_filename % {
            "subtext": text.replace( "\'", "\\\'" ).replace( "\"", "\\\"" ),
            "filename": f"{pngfilename}.png"
        } + f" && magick '{pngfilename}.png' +dither -type palette -remap /tmp/palette.png '{pngfilename}.png'"

        node = self.spunode % {
            "starttime": starttime,
            "endtime": endtime,
            "filename": f"{pngfilename}.png"
        }
        
        print(command)
        os.system( command )
        try:
            self.outfile.write( node )
        except:
            return False
        return True

    def close( self ):
        """ Finalizer function which closes the output file

            Returns:
                True if output file was written and closed succesfully,
                False otherwise
        """
        try:
            self.outfile.write( "    </stream>\n" )
            self.outfile.write( "</subpictures>\n" )
        except:
            return False
        finally:
            if self.outfile != sys.stdout:
                self.outfile.close()
        return True

