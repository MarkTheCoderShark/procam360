import jsPDF from 'jspdf';
import { Photo, Project } from './projects-api';
import { format } from 'date-fns';

export interface ReportOptions {
  title?: string;
  companyName?: string;
  companyLogo?: string; // Base64 image
  includeNotes?: boolean;
  includeLocation?: boolean;
  includeDate?: boolean;
  photosPerPage?: number;
}

export async function generateProjectReport(
  project: Project,
  photos: Photo[],
  options: ReportOptions = {}
): Promise<Blob> {
  const {
    title = `${project.name} - Photo Report`,
    companyName = 'FieldVision',
    companyLogo,
    includeNotes = true,
    includeLocation = true,
    includeDate = true,
    photosPerPage = 2,
  } = options;

  const pdf = new jsPDF('p', 'mm', 'a4');
  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();
  const margin = 15;
  const contentWidth = pageWidth - margin * 2;

  // Colors
  const primaryColor: [number, number, number] = [0, 78, 137]; // FieldVision blue
  const accentColor: [number, number, number] = [255, 107, 53]; // FieldVision orange

  // Helper to load image as base64
  async function loadImageAsBase64(url: string): Promise<string | null> {
    try {
      const response = await fetch(url);
      const blob = await response.blob();
      return new Promise((resolve) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result as string);
        reader.onerror = () => resolve(null);
        reader.readAsDataURL(blob);
      });
    } catch {
      return null;
    }
  }

  // Cover page
  function addCoverPage() {
    // Header bar
    pdf.setFillColor(...accentColor);
    pdf.rect(0, 0, pageWidth, 40, 'F');

    // Company name or logo
    pdf.setTextColor(255, 255, 255);
    pdf.setFontSize(24);
    pdf.setFont('helvetica', 'bold');
    pdf.text(companyName, margin, 27);

    // Report title
    pdf.setTextColor(...primaryColor);
    pdf.setFontSize(28);
    pdf.setFont('helvetica', 'bold');
    pdf.text(title, margin, 70);

    // Project details
    pdf.setFontSize(14);
    pdf.setFont('helvetica', 'normal');
    pdf.setTextColor(100, 100, 100);

    let y = 90;

    pdf.text(`Address: ${project.address}`, margin, y);
    y += 10;

    pdf.text(`Total Photos: ${photos.length}`, margin, y);
    y += 10;

    pdf.text(`Report Generated: ${format(new Date(), 'MMMM d, yyyy')}`, margin, y);
    y += 10;

    // Footer
    pdf.setFontSize(10);
    pdf.setTextColor(150, 150, 150);
    pdf.text('Generated with FieldVision', margin, pageHeight - 15);
  }

  // Photo pages - 1 photo per page, full width
  async function addPhotoPages() {
    const maxPhotoHeight = pageHeight - 60; // Leave room for header and footer
    const photoWidth = contentWidth;

    for (let i = 0; i < photos.length; i++) {
      const photo = photos[i];

      pdf.addPage();

      // Page header
      pdf.setFillColor(...primaryColor);
      pdf.rect(0, 0, pageWidth, 20, 'F');
      pdf.setTextColor(255, 255, 255);
      pdf.setFontSize(12);
      pdf.setFont('helvetica', 'bold');
      pdf.text(project.name, margin, 13);
      pdf.setFont('helvetica', 'normal');
      pdf.text(`Photo ${i + 1} of ${photos.length}`, pageWidth - margin - 35, 13);

      const yOffset = 30;

      // Load and add photo
      const imageData = await loadImageAsBase64(photo.remoteUrl);
      if (imageData) {
        try {
          // Calculate aspect ratio to fit - maximize width
          const img = new Image();
          img.src = imageData;
          await new Promise((resolve) => {
            img.onload = resolve;
            img.onerror = resolve;
          });

          const imgAspect = img.width / img.height;
          let finalWidth = photoWidth;
          let finalHeight = photoWidth / imgAspect;

          // If too tall, scale down to fit
          if (finalHeight > maxPhotoHeight - 30) {
            finalHeight = maxPhotoHeight - 30;
            finalWidth = finalHeight * imgAspect;
          }

          // Center horizontally
          const xOffset = margin + (photoWidth - finalWidth) / 2;

          pdf.addImage(imageData, 'JPEG', xOffset, yOffset, finalWidth, finalHeight);

          // Photo info below image
          const infoY = yOffset + finalHeight + 8;
          pdf.setFontSize(11);
          pdf.setTextColor(80, 80, 80);

          let infoText = '';

          if (includeDate) {
            infoText += format(new Date(photo.capturedAt), 'MMMM d, yyyy \'at\' h:mm a');
          }

          if (includeLocation && photo.latitude && photo.longitude) {
            if (infoText) infoText += '  •  ';
            infoText += `GPS: ${photo.latitude.toFixed(6)}, ${photo.longitude.toFixed(6)}`;
          }

          if (infoText) {
            pdf.text(infoText, margin, infoY);
          }

          if (includeNotes && photo.note) {
            pdf.setFontSize(10);
            pdf.setTextColor(60, 60, 60);
            pdf.setFont('helvetica', 'italic');
            const noteLines = pdf.splitTextToSize(`"${photo.note}"`, contentWidth);
            pdf.text(noteLines.slice(0, 3), margin, infoY + 7);
            pdf.setFont('helvetica', 'normal');
          }
        } catch (e) {
          // If image fails, add placeholder
          pdf.setFillColor(245, 245, 245);
          pdf.rect(margin, yOffset, photoWidth, 150, 'F');
          pdf.setTextColor(150, 150, 150);
          pdf.setFontSize(14);
          pdf.text('Image could not be loaded', pageWidth / 2 - 35, yOffset + 75);
        }
      }
    }
  }

  // Generate the PDF
  addCoverPage();
  await addPhotoPages();

  return pdf.output('blob');
}

export function downloadReport(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
