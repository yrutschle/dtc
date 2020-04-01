
all: figures dataflow_tabular_charts.tex
	pdflatex dataflow_tabular_charts.tex
       
figures: img/dtc_dav.pdf img/dtc_email_desktop.pdf img/dtc_email_sf.pdf img/dtc_email_simple.pdf img/email_above.pdf img/email_above2.pdf img/dtc_email2srv.pdf img/dtc_email2srv_caption.pdf img/dtc_email2srv_icons.pdf img/dtc_function.pdf img/dtc_stacks.pdf

clean:
	rm -rf img/dtc_* img/email_* *.aux *.log *.pdf

# ask Make not to remove intermediary SVG between DTC and PDF
#.PRECIOUS: svg/%.svg

# Nothing else below should need to change

%.pdf: %.tex 
	pdflatex $<

img/%.pdf: svg/%.svg
	inkscape -D -f $< --export-pdf $@

svg/%.svg: dtc/%.dtc
	dtc.pl $< -o $@
